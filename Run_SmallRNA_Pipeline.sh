#!/bin/bash

################################################################################
# Master Small RNA-seq Pipeline Orchestration Script
#
# This script runs the complete mouse small RNA-seq analysis pipeline from
# reference preparation through visualization.
#
# ⚠️  IMPORTANT: Run with bash, NOT sbatch!
#
# Usage:
#   bash Run_SmallRNA_Pipeline.sh [--build-references] [--skip-viz] [--sample NAME]
#
# Options:
#   --build-references    Build genome references (Step 01) - only needed once
#   --skip-viz            Skip coverage visualization (faster completion)
#   --sample NAME         Run only this sample (basename without .fastq.gz, e.g. 204913_combined_R1_001)
#   --help                Show this help message
#
# DO NOT USE:
#   sbatch Run_SmallRNA_Pipeline.sh    ❌ WRONG - this will fail!
#
# This script is an orchestrator that SUBMITS other jobs. Running it with
# sbatch will cause permission and directory issues.
################################################################################

set -euo pipefail

# Safety check: Detect if running under SLURM and warn
if [ -n "${SLURM_JOB_ID:-}" ]; then
    echo "================================================================================"
    echo "ERROR: This script should NOT be submitted with sbatch!"
    echo "================================================================================"
    echo ""
    echo "This is an orchestration script that submits other jobs."
    echo "Running it as a SLURM job causes permission and directory issues."
    echo ""
    echo "Correct usage:"
    echo "  bash Run_SmallRNA_Pipeline.sh [options]"
    echo ""
    echo "NOT:"
    echo "  sbatch Run_SmallRNA_Pipeline.sh  ❌"
    echo ""
    echo "================================================================================"
    exit 1
fi

################################################################################
# CONFIGURATION SECTION - EDIT THESE PATHS FOR YOUR ANALYSIS
################################################################################

# === INPUT FILES ===
# Directory containing your FASTQ files (*.fastq.gz or *.fq.gz)
INPUT_FASTQ_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/fastqs_combined"

# === OUTPUT LOCATION ===
# Main output directory (will create sample subdirectories here)
OUTPUT_BASE_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/miRNA_combined_Fastqs_analysis"

# === REFERENCE GENOME ===
# Reference directory (indices will be built here)
REFERENCE_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references"

# Genome and annotation (auto-downloaded if build-references is used)
GENOME_URL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M38/GRCm39.genome.fa.gz"
GTF_URL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M38/gencode.vM38.annotation.gtf.gz"

# === ADAPTER SEQUENCE ===
# ⚠️  IMPORTANT: Set this to match YOUR library prep kit. Wrong adapter = poor trimming = low miRNA mapping.
# This is the 3' adapter sequence that cutadapt will trim from your reads.
#
# Common options (uncomment the one that matches your kit):

# TruSeq Universal Adapter (used by many Illumina small RNA / RNA-seq kits)
ADAPTER_SEQUENCE="AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"

# Other common adapters:
# ADAPTER_SEQUENCE="TGGAATTCTCGGGTGCCAAGG"           # Illumina TruSeq Small RNA Index (v1.5)
# ADAPTER_SEQUENCE="AGATCGGAAGAGCACACGTCT"          # NEBNext Small RNA
# ADAPTER_SEQUENCE="AAAAAAAAAA"                      # Takara SMARTer (polyA tail)
# ADAPTER_SEQUENCE="AACTGTAGGCACCATCAAT"            # QIAseq miRNA
# ADAPTER_SEQUENCE="YOUR_CUSTOM_ADAPTER_HERE"       # Custom – check kit manual or FastQC overrepresented sequences
#
# To find your adapter sequence:
# 1. Check your library prep kit documentation
# 2. Or run FastQC on raw reads and look at "Overrepresented sequences"
# 3. Or check: https://support-docs.illumina.com/SHARE/AdapterSequences/

# === RESOURCE ALLOCATION ===
# CPUs and memory for different steps (adjust based on your cluster limits)
REF_BUILD_CPUS=16
REF_BUILD_MEM="120G"
REF_BUILD_TIME="4:00:00"

SINGLE_SAMPLE_CPUS=8
SINGLE_SAMPLE_MEM="64G"   # STAR alignment requires ≥64G
SINGLE_SAMPLE_TIME="2:00:00"

RSEM_BATCH_CPUS=8
RSEM_BATCH_MEM="64G"
RSEM_BATCH_TIME="24:00:00"

EMAPPER_BATCH_CPUS=8
EMAPPER_BATCH_MEM="96G"   # EMapper (EM + pyBigWig) requires more memory for 35 samples
EMAPPER_BATCH_TIME="36:00:00"

VIZ_BATCH_CPUS=4
VIZ_BATCH_MEM="32G"
VIZ_BATCH_TIME="8:00:00"

# === SLURM PARTITION ===
PARTITION="cpu"   # Use cpu for idle compute nodes; hmem has only 1 node (often busy)

################################################################################
# END OF CONFIGURATION - DO NOT EDIT BELOW THIS LINE
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
BUILD_REFS=false
SKIP_VIZ=false
TEST_SAMPLE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-references)
            BUILD_REFS=true
            shift
            ;;
        --skip-viz)
            SKIP_VIZ=true
            shift
            ;;
        --sample)
            TEST_SAMPLE="$2"
            shift 2
            ;;
        --help)
            head -n 20 "$0" | grep "^#" | sed 's/^# *//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Change to script directory FIRST
cd "${SCRIPT_DIR}"

# Create necessary directories
mkdir -p "${OUTPUT_BASE_DIR}"
mkdir -p "${OUTPUT_BASE_DIR}/logs"

# Set log directory
LOG_DIR="${OUTPUT_BASE_DIR}/logs"

# Header
echo "================================================================================"
echo "MOUSE SMALL RNA-SEQ PIPELINE"
echo "================================================================================"
echo "Date: $(date)"
echo "Pipeline directory: ${SCRIPT_DIR}"
echo "Input directory: ${INPUT_FASTQ_DIR}"
echo "Output directory: ${OUTPUT_BASE_DIR}"
echo "Log directory: ${LOG_DIR}"
echo "Reference directory: ${REFERENCE_DIR}"
echo "Adapter sequence: ${ADAPTER_SEQUENCE}"
echo "Partition: ${PARTITION}"
echo ""
echo "Options:"
echo "  Build references: ${BUILD_REFS}"
echo "  Skip visualization: ${SKIP_VIZ}"
echo "  Test sample only: ${TEST_SAMPLE:-all}"
echo "================================================================================"
echo ""

# Check if input directory exists
if [ ! -d "${INPUT_FASTQ_DIR}" ]; then
    echo "ERROR: Input directory not found: ${INPUT_FASTQ_DIR}"
    echo "Please edit the INPUT_FASTQ_DIR variable in this script"
    exit 1
fi

# Check if FASTQ files exist
FASTQ_COUNT=$(find "${INPUT_FASTQ_DIR}" -maxdepth 1 -name "*.fastq.gz" -o -name "*.fq.gz" | wc -l)
if [ ${FASTQ_COUNT} -eq 0 ]; then
    echo "ERROR: No FASTQ files found in ${INPUT_FASTQ_DIR}"
    echo "Looking for: *.fastq.gz or *.fq.gz"
    exit 1
fi

echo "Found ${FASTQ_COUNT} FASTQ file(s) in input directory"
echo ""

# Job ID tracking
JOB_IDS=()
JOB_NAMES=()

################################################################################
# STEP 01: BUILD REFERENCES (Optional, one-time setup)
################################################################################

if [ "${BUILD_REFS}" = true ]; then
    echo "=== STEP 01: Building Genome References ==="
    echo ""
    
    # Check if references already exist
    if [ -f "${REFERENCE_DIR}/indices/STAR/SAindex" ]; then
        echo "⚠️  WARNING: References already exist at ${REFERENCE_DIR}"
        echo "   Continuing will rebuild all indices (this takes ~2 hours)"
        read -p "   Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping reference building"
            BUILD_REFS=false
        fi
    fi
    
    if [ "${BUILD_REFS}" = true ]; then
        echo "Submitting reference building job..."
        
        # Create temporary script with updated resources
        cat > "${SCRIPT_DIR}/.tmp_01_refs.sh" << EOF
#!/bin/bash
#SBATCH --job-name=build_refs
#SBATCH --output=${LOG_DIR}/01_build_refs_%j.log
#SBATCH --error=${LOG_DIR}/01_build_refs_%j.err
#SBATCH --time=${REF_BUILD_TIME}
#SBATCH --cpus-per-task=${REF_BUILD_CPUS}
#SBATCH --mem=${REF_BUILD_MEM}
#SBATCH --partition=${PARTITION}

${SCRIPT_DIR}/01_prepare_mouse_references.sh ${REF_BUILD_CPUS}
EOF
        
        REF_JOB=$(sbatch --parsable .tmp_01_refs.sh)
        rm .tmp_01_refs.sh
        
        JOB_IDS+=("${REF_JOB}")
        JOB_NAMES+=("Reference Building")
        
        echo "  ✓ Job ID: ${REF_JOB}"
        echo "  Resources: ${REF_BUILD_CPUS} CPUs, ${REF_BUILD_MEM} memory, ${REF_BUILD_TIME}"
        echo ""
    fi
else
    # Check if references exist
    if [ ! -f "${REFERENCE_DIR}/indices/STAR/SAindex" ]; then
        echo "ERROR: References not found at ${REFERENCE_DIR}"
        echo "Please run with --build-references first:"
        echo "  bash Run_SmallRNA_Pipeline.sh --build-references"
        exit 1
    fi
    echo "✓ Using existing references at ${REFERENCE_DIR}"
    echo ""
fi

################################################################################
# STEP 02-03: PROCESS INDIVIDUAL SAMPLES
################################################################################

echo "=== STEP 02-03: Processing Individual Samples ==="
echo ""

SAMPLE_JOBS=()
SAMPLE_COUNT=0

# Process each FASTQ file
for FASTQ in "${INPUT_FASTQ_DIR}"/*.{fastq.gz,fq.gz}; do
    [ -e "$FASTQ" ] || continue
    
    # Extract sample name (remove path and extension)
    SAMPLE_NAME=$(basename "$FASTQ" | sed -E 's/\.(fastq|fq)\.gz$//')
    
    # If --sample was set, only process that sample
    if [ -n "${TEST_SAMPLE}" ] && [ "${SAMPLE_NAME}" != "${TEST_SAMPLE}" ]; then
        continue
    fi
    
    # Check if already processed (use featureCounts TPM as completion marker;
    # RSEM TPM is optional and may not exist if RSEM was skipped)
    if [ -f "${OUTPUT_BASE_DIR}/${SAMPLE_NAME}_output/04_expression/${SAMPLE_NAME}_featureCounts_TPM.tsv" ]; then
        echo "  ⊙ ${SAMPLE_NAME} - Already processed, skipping"
        continue
    fi
    
    echo "  Submitting ${SAMPLE_NAME}..."
    
    # Create temporary submission script
    cat > "${SCRIPT_DIR}/.tmp_sample_${SAMPLE_NAME}.sh" << EOF
#!/bin/bash
#SBATCH --job-name=${SAMPLE_NAME}
#SBATCH --output=${LOG_DIR}/02_${SAMPLE_NAME}_%j.log
#SBATCH --error=${LOG_DIR}/02_${SAMPLE_NAME}_%j.err
#SBATCH --time=${SINGLE_SAMPLE_TIME}
#SBATCH --cpus-per-task=${SINGLE_SAMPLE_CPUS}
#SBATCH --mem=${SINGLE_SAMPLE_MEM}
#SBATCH --partition=${PARTITION}

${SCRIPT_DIR}/02_smRNA_analysis.sh ${SAMPLE_NAME} ${FASTQ} \\
    --threads ${SINGLE_SAMPLE_CPUS} \\
    --output-dir ${OUTPUT_BASE_DIR}/${SAMPLE_NAME}_output \\
    --adapter ${ADAPTER_SEQUENCE}
EOF
    
    # Submit with dependency on reference building if needed
    if [ "${BUILD_REFS}" = true ]; then
        SAMPLE_JOB=$(sbatch --parsable --dependency=afterok:${REF_JOB} .tmp_sample_${SAMPLE_NAME}.sh)
    else
        SAMPLE_JOB=$(sbatch --parsable .tmp_sample_${SAMPLE_NAME}.sh)
    fi
    
    rm .tmp_sample_${SAMPLE_NAME}.sh
    
    SAMPLE_JOBS+=("${SAMPLE_JOB}")
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
    
    echo "    Job ID: ${SAMPLE_JOB}"
done

if [ ${SAMPLE_COUNT} -eq 0 ]; then
    echo "  ⊙ All samples already processed"
    echo ""
else
    echo ""
    echo "  ✓ Submitted ${SAMPLE_COUNT} sample(s)"
    echo ""
fi

################################################################################
# STEP 04: RSEM QUANTIFICATION (BATCH)
################################################################################

echo "=== STEP 04: RSEM Quantification (Batch) ==="
echo ""

# Create dependency string for sample jobs
if [ ${#SAMPLE_JOBS[@]} -gt 0 ]; then
    SAMPLE_DEPS=$(IFS=:; echo "${SAMPLE_JOBS[*]}")
    RSEM_DEPENDENCY="--dependency=afterok:${SAMPLE_DEPS}"
else
    RSEM_DEPENDENCY=""
fi

echo "Submitting RSEM batch job..."

# Create temporary wrapper script
cat > "${SCRIPT_DIR}/.tmp_rsem.sh" << EOF
#!/bin/bash
#SBATCH --job-name=rsem_batch
#SBATCH --output=${LOG_DIR}/04_rsem_batch_%j.log
#SBATCH --error=${LOG_DIR}/04_rsem_batch_%j.err
#SBATCH --time=${RSEM_BATCH_TIME}
#SBATCH --cpus-per-task=${RSEM_BATCH_CPUS}
#SBATCH --mem=${RSEM_BATCH_MEM}
#SBATCH --partition=${PARTITION}

# Run script from correct directory
cd ${SCRIPT_DIR}

export OUTPUT_BASE="${OUTPUT_BASE_DIR}"
bash 04_rerun_rsem_all_samples.sh
EOF

RSEM_JOB=$(sbatch --parsable ${RSEM_DEPENDENCY} .tmp_rsem.sh)
rm .tmp_rsem.sh

JOB_IDS+=("${RSEM_JOB}")
JOB_NAMES+=("RSEM Quantification")

echo "  ✓ Job ID: ${RSEM_JOB}"
if [ ${#SAMPLE_JOBS[@]} -gt 0 ]; then
    echo "  Depends on: ${SAMPLE_COUNT} sample job(s)"
fi
echo "  Resources: ${RSEM_BATCH_CPUS} CPUs, ${RSEM_BATCH_MEM} memory, ${RSEM_BATCH_TIME}"
echo ""

################################################################################
# STEP 05: EMAPPER COVERAGE
################################################################################

echo "=== STEP 05: EMapper Coverage Calculation ==="
echo ""

echo "Submitting EMapper jobs as a SLURM array (one task per sample)..."

# Determine number of samples for EMapper
EMAPPER_SAMPLE_COUNT=$(find "${OUTPUT_BASE_DIR}" -maxdepth 1 -type d -name "*_output" | wc -l)

if [ "${EMAPPER_SAMPLE_COUNT}" -eq 0 ]; then
    echo "ERROR: No sample output directories found for EMapper in ${OUTPUT_BASE_DIR}"
    exit 1
fi

# Create temporary wrapper script
cat > "${SCRIPT_DIR}/.tmp_emapper.sh" << EOF
#!/bin/bash
#SBATCH --job-name=emapper
#SBATCH --output=${LOG_DIR}/05_emapper_%A_%a.log
#SBATCH --error=${LOG_DIR}/05_emapper_%A_%a.err
#SBATCH --time=${EMAPPER_BATCH_TIME}
#SBATCH --cpus-per-task=${EMAPPER_BATCH_CPUS}
#SBATCH --mem=${EMAPPER_BATCH_MEM}
#SBATCH --partition=${PARTITION}
#SBATCH --array=1-${EMAPPER_SAMPLE_COUNT}

# Run script from correct directory
cd ${SCRIPT_DIR}

export OUTPUT_BASE="${OUTPUT_BASE_DIR}"
bash 05_run_emapper_all_samples.sh
EOF

EMAPPER_JOB=$(sbatch --parsable --dependency=afterok:${RSEM_JOB} .tmp_emapper.sh)
rm .tmp_emapper.sh

JOB_IDS+=("${EMAPPER_JOB}")
JOB_NAMES+=("EMapper Coverage")

echo "  ✓ Job ID: ${EMAPPER_JOB}"
echo "  Depends on: RSEM job ${RSEM_JOB}"
echo "  Resources: ${EMAPPER_BATCH_CPUS} CPUs, ${EMAPPER_BATCH_MEM} memory, ${EMAPPER_BATCH_TIME}"
echo ""

################################################################################
# STEP 06: COVERAGE VISUALIZATION (Optional)
################################################################################

if [ "${SKIP_VIZ}" = false ]; then
    echo "=== STEP 06: Coverage Visualization ==="
    echo ""
    
    echo "Submitting visualization job..."
    
    # Create temporary wrapper script
    cat > "${SCRIPT_DIR}/.tmp_viz.sh" << EOF
#!/bin/bash
#SBATCH --job-name=coverage_viz
#SBATCH --output=${LOG_DIR}/06_viz_%j.log
#SBATCH --error=${LOG_DIR}/06_viz_%j.err
#SBATCH --time=${VIZ_BATCH_TIME}
#SBATCH --cpus-per-task=${VIZ_BATCH_CPUS}
#SBATCH --mem=${VIZ_BATCH_MEM}
#SBATCH --partition=${PARTITION}

# Run script from correct directory
cd ${SCRIPT_DIR}

export OUTPUT_BASE="${OUTPUT_BASE_DIR}"
bash 06_visualize_coverage.sh
EOF
    
    VIZ_JOB=$(sbatch --parsable --dependency=afterok:${EMAPPER_JOB} .tmp_viz.sh)
    rm .tmp_viz.sh
    
    JOB_IDS+=("${VIZ_JOB}")
    JOB_NAMES+=("Coverage Visualization")
    
    echo "  ✓ Job ID: ${VIZ_JOB}"
    echo "  Depends on: EMapper job ${EMAPPER_JOB}"
    echo "  Resources: ${VIZ_BATCH_CPUS} CPUs, ${VIZ_BATCH_MEM} memory, ${VIZ_BATCH_TIME}"
    echo ""
else
    echo "=== STEP 06: Coverage Visualization (SKIPPED) ==="
    echo ""
fi

################################################################################
# SUMMARY
################################################################################

echo "================================================================================"
echo "PIPELINE SUBMITTED SUCCESSFULLY"
echo "================================================================================"
echo "Date: $(date)"
echo ""
echo "Submitted Jobs:"
for i in "${!JOB_IDS[@]}"; do
    echo "  ${JOB_NAMES[$i]}: ${JOB_IDS[$i]}"
done
echo ""
echo "Input: ${FASTQ_COUNT} FASTQ file(s) from ${INPUT_FASTQ_DIR}"
echo "Output: ${OUTPUT_BASE_DIR}"
echo ""
echo "================================================================================"
echo "MONITORING"
echo "================================================================================"
echo ""
echo "Check job status:"
echo "  squeue -u \$USER"
echo ""
echo "Monitor specific jobs:"
echo "  sacct -j $(IFS=,; echo "${JOB_IDS[*]}") --format=JobID,JobName,State,Elapsed"
echo ""
echo "View logs:"
if [ "${BUILD_REFS}" = true ]; then
    echo "  tail -f ${LOG_DIR}/01_build_refs_${JOB_IDS[0]}.log"
fi
echo "  tail -f ${LOG_DIR}/04_rsem_batch_${RSEM_JOB}.log"
echo "  tail -f ${LOG_DIR}/05_emapper_${EMAPPER_JOB}.log"
if [ "${SKIP_VIZ}" = false ]; then
    echo "  tail -f ${LOG_DIR}/06_viz_${VIZ_JOB}.log"
fi
echo ""
echo "================================================================================"
echo "EXPECTED OUTPUT"
echo "================================================================================"
echo ""
echo "For each sample, you will get:"
echo "  ${OUTPUT_BASE_DIR}/SAMPLE_output/"
echo "    ├── 01_trimmed/              # Trimmed FASTQ"
echo "    ├── 02_aligned/              # BAM files"
echo "    ├── 03_counts/               # featureCounts and RSEM results"
echo "    ├── 04_expression/           # TPM matrices and plots"
echo "    │   ├── *_RSEM_TPM.tsv"
echo "    │   ├── *_miRNAs_only_RSEM.tsv"
echo "    │   ├── *_GeneType_Barplot.pdf"
echo "    │   ├── *_RNA_distribution_2subplots.pdf"
echo "    │   └── *_top_expressed_genes.pdf"
echo "    ├── 05_qc/                   # FastQC reports"
echo "    ├── 06_emapper/              # BigWig coverage files"
if [ "${SKIP_VIZ}" = false ]; then
    echo "    ├── 07_coverage_plots/       # Coverage visualization"
fi
echo "    └── logs/                    # Per-sample logs"
echo ""
echo "================================================================================"
echo "ESTIMATED COMPLETION TIMES"
echo "================================================================================"
echo ""
if [ "${BUILD_REFS}" = true ]; then
    echo "  Reference building:  ~2-4 hours"
fi
if [ ${SAMPLE_COUNT} -gt 0 ]; then
    echo "  Sample processing:   ~1-2 hours per sample"
fi
echo "  RSEM batch:          ~12-24 hours (all samples)"
echo "  EMapper:             ~6-12 hours (all samples)"
if [ "${SKIP_VIZ}" = false ]; then
    echo "  Visualization:       ~4-8 hours (all samples)"
fi
echo ""
echo "Total pipeline time:   ~24-48 hours (depends on sample count)"
echo ""
echo "================================================================================"

# Create job tracking file
cat > "${LOG_DIR}/pipeline_jobs_$(date +%Y%m%d_%H%M%S).txt" << EOF
Pipeline Submission: $(date)
Configuration: ${SCRIPT_DIR}
Input: ${INPUT_FASTQ_DIR}
Output: ${OUTPUT_BASE_DIR}
Adapter: ${ADAPTER_SEQUENCE}

Submitted Jobs:
$(for i in "${!JOB_IDS[@]}"; do echo "  ${JOB_NAMES[$i]}: ${JOB_IDS[$i]}"; done)

Monitor command:
squeue -u \$USER
sacct -j $(IFS=,; echo "${JOB_IDS[*]}") --format=JobID,JobName,State,Elapsed,MaxRSS
EOF

echo "✓ Job tracking saved to ${LOG_DIR}/pipeline_jobs_*.txt"
echo ""
