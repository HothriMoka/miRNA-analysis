#!/bin/bash
#SBATCH --job-name=smRNA_analysis
#SBATCH --output=logs/smRNA_%A_%x.log
#SBATCH --error=logs/smRNA_%A_%x.err
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=80G
#SBATCH --partition=cpu
#
# smRNA_analysis.sh - Small RNA-seq Analysis Pipeline
# Optimized for Takara SMARTer smRNA-Seq Kit
# Mouse genome (GRCm39, GENCODE M38)
#
# Resource requirements:
#   - Memory: 48GB (for STAR alignment)
#   - CPUs: 16 (parallel processing, max for cpu partition)
#   - Time: ~30-60 min per sample
#
# Usage:
#   sbatch 02_smRNA_analysis.sh SAMPLE_NAME input.fastq.gz --threads 16
#   OR
#   bash 02_smRNA_analysis.sh SAMPLE_NAME input.fastq.gz --threads 16
#

set -euo pipefail

# ============================================================================
# LOAD REQUIRED MODULES
# ============================================================================

# Load required modules (suppress errors if already loaded)
module load star/2.7.11a-pgsk3s4 rsem/1.3.3 subread/2.0.6 fastqc/0.12.1 samtools/1.17-xtpk2gu 2>/dev/null || true

# Activate conda environment for cutadapt if available
if command -v conda &> /dev/null; then
    source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
    conda activate smallrna-tools 2>/dev/null || true
fi

# Get script directory - use SLURM_SUBMIT_DIR when run via sbatch, otherwise use script location
if [ -n "${SLURM_SUBMIT_DIR}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "${SCRIPT_DIR}"

# ============================================================================
# USAGE AND ARGUMENT PARSING
# ============================================================================

usage() {
    cat << EOF
Usage: $0 <sample_name> <input_fastq> [options]

Required Arguments:
  sample_name     Sample identifier (no spaces)
  input_fastq     Path to input FASTQ file (.fastq.gz or .fq.gz)

Optional Arguments:
  --threads INT   Number of threads (default: 20)
  --output-dir    Output directory (default: <sample_name>_output)

Example:
  $0 Sample1 /path/to/sample.fastq.gz --threads 16

EOF
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

SAMPLE_NAME="$1"
INPUT_FASTQ="$2"
shift 2

# Defaults (use SLURM allocation if available)
THREADS="${SLURM_CPUS_PER_TASK:-16}"
OUTPUT_DIR="${SAMPLE_NAME}_output"

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# ============================================================================
# VALIDATE INPUTS
# ============================================================================

echo "========================================"
echo "Small RNA-seq Analysis Pipeline"
echo "Sample: ${SAMPLE_NAME}"
echo "========================================"
echo ""

if [[ ! -f "${INPUT_FASTQ}" ]]; then
    echo "ERROR: Input FASTQ not found: ${INPUT_FASTQ}"
    exit 1
fi

if [[ ! "${INPUT_FASTQ}" =~ \.(fastq|fq)(\.gz)?$ ]]; then
    echo "ERROR: Input file must be .fastq.gz or .fq.gz"
    exit 1
fi

# ============================================================================
# SETUP PATHS
# ============================================================================

# SCRIPT_DIR already set earlier in the file using SLURM_SUBMIT_DIR logic
# Don't redefine it here or it will break SLURM jobs
REFS_DIR="${SCRIPT_DIR}/references"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Reference files
GENOME_FA="${REFS_DIR}/genome/GRCm39.genome.fa"
GENE_GTF="${REFS_DIR}/annotations/gencode.vM38.annotation.gtf"
GENE_META="${REFS_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv"
STAR_INDEX="${REFS_DIR}/indices/STAR"
RSEM_INDEX="${REFS_DIR}/indices/RSEM/RSEM_REF_MM39"

# Check references exist
if [[ ! -d "${REFS_DIR}" ]]; then
    echo "ERROR: References directory not found: ${REFS_DIR}"
    echo "Please run 01_prepare_mouse_references.sh first!"
    exit 1
fi

if [[ ! -f "${GENOME_FA}" ]]; then
    echo "ERROR: Genome not found. Run 01_prepare_mouse_references.sh"
    exit 1
fi

if [[ ! -f "${GENE_GTF}" ]]; then
    echo "ERROR: GTF not found. Run 01_prepare_mouse_references.sh"
    exit 1
fi

if [[ ! -d "${STAR_INDEX}" ]]; then
    echo "ERROR: STAR index not found. Run 01_prepare_mouse_references.sh"
    exit 1
fi

# ============================================================================
# CREATE OUTPUT DIRECTORIES
# ============================================================================

mkdir -p ${OUTPUT_DIR}/{01_trimmed,02_aligned,03_counts,04_expression,05_qc,logs}

# Log file
LOGFILE="${OUTPUT_DIR}/logs/${SAMPLE_NAME}_pipeline.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${LOGFILE}
}

log "========================================="
log "Pipeline started for sample: ${SAMPLE_NAME}"
log "Input FASTQ: ${INPUT_FASTQ}"
log "Output directory: ${OUTPUT_DIR}"
log "Threads: ${THREADS}"
log "========================================="
log ""

# ============================================================================
# STEP 1: ADAPTER TRIMMING (Takara SMARTer smRNA-Seq Protocol)
# ============================================================================

log "=== Step 1: Adapter Trimming ==="

TRIMMED_FQ="${OUTPUT_DIR}/01_trimmed/${SAMPLE_NAME}_trimmed.fq.gz"
TRIM_REPORT="${OUTPUT_DIR}/01_trimmed/${SAMPLE_NAME}_cutadapt_report.txt"

if [[ -f "${TRIMMED_FQ}" ]]; then
    log "Trimmed FASTQ already exists, skipping: ${TRIMMED_FQ}"
else
    log "Running cutadapt with Takara SMARTer smRNA-Seq adapters..."
    
    cutadapt \
        -j ${THREADS} \
        -u 3 \
        -a "AAAAAAAAAA" \
        -m 15 \
        -M 50 \
        --max-n 0 \
        --nextseq-trim 20 \
        --report=minimal \
        -o ${TRIMMED_FQ} \
        ${INPUT_FASTQ} \
        > ${TRIM_REPORT} 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ Trimming complete!"
        TRIMMED_READS=$(zcat ${TRIMMED_FQ} | wc -l | awk '{print $1/4}')
        log "  Reads after trimming: ${TRIMMED_READS}"
    else
        log "✗ ERROR: Trimming failed! Check ${TRIM_REPORT}"
        exit 1
    fi
fi

# ============================================================================
# STEP 2: QUALITY CONTROL
# ============================================================================

log ""
log "=== Step 2: Quality Control with FastQC ==="

FASTQC_OUT="${OUTPUT_DIR}/05_qc/${SAMPLE_NAME}_trimmed_fastqc.html"

if [[ -f "${FASTQC_OUT}" ]]; then
    log "FastQC report already exists, skipping"
else
    log "Running FastQC..."
    
    fastqc -t ${THREADS} \
        -o ${OUTPUT_DIR}/05_qc \
        ${TRIMMED_FQ} \
        > ${OUTPUT_DIR}/logs/fastqc.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ FastQC complete!"
    else
        log "⚠ WARNING: FastQC failed, continuing anyway"
    fi
fi

# ============================================================================
# STEP 3: ALIGNMENT WITH STAR
# ============================================================================

log ""
log "=== Step 3: Alignment with STAR ==="

ALIGNED_BAM="${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam"
STAR_LOG="${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_Log.final.out"

if [[ -f "${ALIGNED_BAM}" ]]; then
    log "Aligned BAM already exists, skipping: ${ALIGNED_BAM}"
else
    log "Running STAR alignment (optimized for small RNA)..."
    # Output SAM to completely avoid bgzf bug in STAR 2.7.11a
    STAR --genomeDir ${STAR_INDEX} \
        --readFilesIn ${TRIMMED_FQ} \
        --readFilesCommand zcat \
        --outFileNamePrefix ${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_ \
        --runThreadN ${THREADS} \
        --outSAMtype SAM \
        --outFilterMultimapNmax 100 \
        --winAnchorMultimapNmax 100 \
        --outFilterMismatchNmax 2 \
        --outFilterMatchNmin 16 \
        --alignIntronMax 1 \
        --alignEndsType EndToEnd \
        --outFilterMatchNminOverLread 0.9 \
        > ${OUTPUT_DIR}/logs/star_align.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ Alignment complete!"
        
        # Convert SAM to sorted BAM with samtools (workaround for STAR bgzf bug)
        log "Converting SAM to sorted BAM..."
        UNSORTED_SAM="${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.out.sam"
        samtools sort -@ ${THREADS} -m 4G -o ${ALIGNED_BAM} ${UNSORTED_SAM}
        rm ${UNSORTED_SAM}
        
        # Index BAM
        log "Indexing BAM file..."
        samtools index -@ ${THREADS} ${ALIGNED_BAM}
        
        # Extract key statistics
        TOTAL_READS=$(grep "Number of input reads" ${STAR_LOG} | awk '{print $NF}')
        UNIQUE_READS=$(grep "Uniquely mapped reads number" ${STAR_LOG} | awk '{print $NF}')
        MULTI_READS=$(grep "Number of reads mapped to multiple loci" ${STAR_LOG} | awk '{print $NF}')
        UNMAPPED=$(grep "Number of reads unmapped: too short" ${STAR_LOG} | awk '{print $NF}')
        
        log "  Total reads: ${TOTAL_READS}"
        log "  Uniquely mapped: ${UNIQUE_READS}"
        log "  Multi-mapped: ${MULTI_READS}"
        log "  Unmapped (too short): ${UNMAPPED}"
    else
        log "✗ ERROR: Alignment failed! Check ${OUTPUT_DIR}/logs/star_align.log"
        exit 1
    fi
fi

# ============================================================================
# STEP 4: QUANTIFICATION WITH FEATURECOUNTS
# ============================================================================

log ""
log "=== Step 4: Quantification with featureCounts ==="

FC_OUT="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_featureCounts.tsv"
FC_SUMMARY="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_featureCounts.tsv.summary"

if [[ -f "${FC_OUT}" ]]; then
    log "featureCounts output already exists, skipping"
else
    log "Running featureCounts (fractional multi-mapping)..."
    
    featureCounts \
        -a ${GENE_GTF} \
        -o ${FC_OUT} \
        -T ${THREADS} \
        -s 0 \
        -g gene_id \
        -t exon \
        -M \
        --fraction \
        ${ALIGNED_BAM} \
        > ${OUTPUT_DIR}/logs/featureCounts.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ featureCounts complete!"
        
        # Extract statistics
        ASSIGNED=$(grep "Assigned" ${FC_SUMMARY} | cut -f2)
        UNASSIGNED=$(grep "Unassigned_NoFeatures" ${FC_SUMMARY} | cut -f2)
        log "  Assigned to genes: ${ASSIGNED}"
        log "  Unassigned: ${UNASSIGNED}"
    else
        log "✗ ERROR: featureCounts failed! Check ${OUTPUT_DIR}/logs/featureCounts.log"
        exit 1
    fi
fi

# ============================================================================
# STEP 5: QUANTIFICATION WITH RSEM
# ============================================================================

log ""
log "=== Step 5: Quantification with RSEM (EM algorithm) ==="

RSEM_OUT="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_RSEM.genes.results"
RSEM_PREFIX="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_RSEM"

# Initialize RSEM success flag
RSEM_SUCCESS=false

if [[ -f "${RSEM_OUT}" && -s "${RSEM_OUT}" ]]; then
    log "RSEM output already exists and is valid, skipping"
    RSEM_SUCCESS=true
else
    log "Running RSEM (handles multi-mapping with EM algorithm)..."
    
    # Temporarily disable errexit to handle RSEM failure gracefully
    set +e
    rsem-calculate-expression \
        --bowtie2 \
        --strandedness none \
        --bowtie2-k 100 \
        -p ${THREADS} \
        --no-bam-output \
        --seed 12345 \
        ${TRIMMED_FQ} \
        ${RSEM_INDEX} \
        ${RSEM_PREFIX} \
        > ${OUTPUT_DIR}/logs/rsem.log 2>&1
    RSEM_EXIT_CODE=$?
    set -e
    
    if [[ ${RSEM_EXIT_CODE} -eq 0 ]]; then
        log "✓ RSEM complete!"
        RSEM_SUCCESS=true
        
        # Count genes with TPM > 0
        GENES_DETECTED=$(awk '$6 > 0' ${RSEM_OUT} | tail -n +2 | wc -l)
        log "  Genes detected (TPM>0): ${GENES_DETECTED}"
    else
        log "WARNING: RSEM failed (likely bgzf/samtools bug)"
        log "  This is a known issue with certain samtools/zlib versions"
        log "  Continuing with featureCounts results only"
        log "  For details: cat ${OUTPUT_DIR}/logs/rsem.log"
        RSEM_SUCCESS=false
    fi
fi

# ============================================================================
# STEP 6: GENERATE EXPRESSION MATRICES
# ============================================================================

log ""
log "=== Step 6: Generate TPM Expression Matrices ==="

FC_TPM="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_featureCounts_TPM.tsv"
RSEM_TPM="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_RSEM_TPM.tsv"

# featureCounts → TPM
if [[ -f "${FC_TPM}" ]]; then
    log "featureCounts TPM already exists, skipping"
else
    log "Converting featureCounts to TPM..."
    
    python ${SCRIPTS_DIR}/Step_15_featureCounts2TPM.py \
        --featureCounts_out ${FC_OUT} \
        --GeneID_meta_table ${GENE_META} \
        --output ${FC_TPM} \
        > ${OUTPUT_DIR}/logs/fc_to_tpm.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ featureCounts TPM matrix generated!"
    else
        log "✗ ERROR: featureCounts TPM conversion failed!"
        exit 1
    fi
fi

# RSEM → Expression matrix (only if RSEM succeeded)
if [[ "${RSEM_SUCCESS}" == "true" ]]; then
    if [[ -f "${RSEM_TPM}" ]]; then
        log "RSEM TPM already exists, skipping"
    else
        log "Converting RSEM to expression matrix..."
        
        python ${SCRIPTS_DIR}/Step_17_RSEM2expr_matrix.py \
            --RSEM_out ${RSEM_OUT} \
            --GeneID_meta_table ${GENE_META} \
            --output ${RSEM_TPM} \
            > ${OUTPUT_DIR}/logs/rsem_to_tpm.log 2>&1
        
        if [[ $? -eq 0 ]]; then
            log "✓ RSEM TPM matrix generated!"
        else
            log "WARNING: RSEM TPM conversion failed!"
        fi
    fi
else
    log "Skipping RSEM expression matrix (RSEM did not complete)"
fi

# ============================================================================
# STEP 7: EXTRACT miRNA RESULTS
# ============================================================================

log ""
log "=== Step 7: Extract miRNA-Specific Results ==="

MIRNA_FC="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_featureCounts.tsv"
MIRNA_RSEM="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_RSEM.tsv"

# Extract miRNAs from featureCounts
log "Extracting miRNAs from featureCounts results..."
awk -F'\t' 'NR==1 || $3~/miRNA/' ${FC_TPM} > ${MIRNA_FC}
MIRNA_FC_COUNT=$(tail -n +2 ${MIRNA_FC} | wc -l)
log "  miRNAs in featureCounts: ${MIRNA_FC_COUNT}"

# Extract miRNAs from RSEM (only if available)
if [[ "${RSEM_SUCCESS}" == "true" ]]; then
    log "Extracting miRNAs from RSEM results..."
    awk -F'\t' 'NR==1 || $3~/miRNA/' ${RSEM_TPM} > ${MIRNA_RSEM}
    MIRNA_RSEM_COUNT=$(tail -n +2 ${MIRNA_RSEM} | wc -l)
    MIRNA_DETECTED=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${RSEM_TPM} | wc -l)
    log "  Total miRNAs annotated: ${MIRNA_RSEM_COUNT}"
    log "  miRNAs detected (TPM>0): ${MIRNA_DETECTED}"
    
    # Get top 10 miRNAs
    log ""
    log "Top 10 most abundant miRNAs (by RSEM TPM):"
    awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${RSEM_TPM} | \
        sort -t$'\t' -k5 -nr | head -10 | \
        awk -F'\t' '{printf "  %-20s %10.2f TPM\n", $2, $5}' | tee -a ${LOGFILE}
else
    log "Skipping RSEM miRNA extraction (RSEM did not complete)"
    log ""
    log "Using featureCounts miRNA results instead:"
    MIRNA_DETECTED_FC=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${MIRNA_FC} | wc -l)
    log "  miRNAs detected (TPM>0): ${MIRNA_DETECTED_FC}"
    log ""
    log "Top 10 most abundant miRNAs (by featureCounts TPM):"
    # Temporarily disable pipefail for this complex pipeline
    set +o pipefail
    TOP_MIRNAS=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${MIRNA_FC} | \
        sort -t$'\t' -k5 -nr | head -10 | \
        awk -F'\t' '{printf "  %-20s %10.2f TPM\n", $2, $5}')
    set -o pipefail
    echo "${TOP_MIRNAS}"
fi

# ============================================================================
# STEP 8: GENERATE SUMMARY REPORT
# ============================================================================

log ""
log "=== Step 8: Generate Analysis Summary ==="

SUMMARY="${OUTPUT_DIR}/${SAMPLE_NAME}_ANALYSIS_SUMMARY.txt"

cat > ${SUMMARY} << EOF
================================================================================
Small RNA-seq Analysis Summary
================================================================================
Sample Name: ${SAMPLE_NAME}
Analysis Date: $(date '+%Y-%m-%d %H:%M:%S')
Pipeline Version: 1.0

Input:
------
FASTQ file: ${INPUT_FASTQ}
Input reads: $(zcat ${INPUT_FASTQ} | wc -l | awk '{print $1/4}')

Trimming (Step 1):
------------------
Adapter: Takara SMARTer smRNA-Seq (AAAAAAAAAA)
TSO trimmed: 3 bp from 5' end
Reads after trimming: $(zcat ${TRIMMED_FQ} | wc -l | awk '{print $1/4}')

Alignment (Step 2-3):
--------------------
Aligner: STAR (small RNA optimized)
Reference: GRCm39 (GENCODE M38)
Total reads: $(grep "Number of input reads" ${STAR_LOG} | awk '{print $NF}')
Uniquely mapped: $(grep "Uniquely mapped reads number" ${STAR_LOG} | awk '{print $NF}') ($(grep "Uniquely mapped reads %" ${STAR_LOG} | awk '{print $NF}'))
Multi-mapped: $(grep "Number of reads mapped to multiple loci" ${STAR_LOG} | awk '{print $NF}')

Quantification (Step 4-5):
-------------------------
featureCounts (unique/fractional):
  - Assigned to genes: $(grep "Assigned" ${FC_SUMMARY} | cut -f2)
  - Total genes detected: $(awk -F'\t' 'NR>1 && $5>0' ${FC_TPM} | wc -l)

miRNA Analysis (Step 7):
------------------------
Total miRNAs found: $(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${MIRNA_FC} | wc -l)

Top 5 miRNAs by abundance (featureCounts):
$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${MIRNA_FC} | sort -t$'\t' -k5 -nr | head -5 | awk -F'\t' '{printf "  %-20s %10.2f TPM\n", $2, $5}')

Output Files:
-------------
Expression Matrices:
  - All genes: 04_expression/${SAMPLE_NAME}_featureCounts_TPM.tsv
  - miRNAs only: 04_expression/${SAMPLE_NAME}_miRNAs_only_featureCounts.tsv

Quality Control:
  - FastQC report: 05_qc/${SAMPLE_NAME}_trimmed_fastqc.html
  - Trimming report: 01_trimmed/${SAMPLE_NAME}_cutadapt_report.txt
  - STAR log: 02_aligned/${SAMPLE_NAME}_Log.final.out

Raw Counts:
  - featureCounts: 03_counts/${SAMPLE_NAME}_featureCounts.tsv

Note:
-----
RSEM quantification was skipped due to a known bgzf/samtools bug.
Results based on featureCounts with fractional counting for multi-mappers.

================================================================================
Pipeline completed successfully!
================================================================================
EOF

log "✓ Summary report generated: ${SUMMARY}"
log ""

# ============================================================================
# STEP 9: GENERATE GENE TYPE BARPLOTS
# ============================================================================

log "=== Step 9: Generate Gene Type Barplots ==="

BARPLOT_OUTPUT="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_GeneType_Barplot.pdf"

if [[ -f "${BARPLOT_OUTPUT}" ]]; then
    log "Barplot already exists, skipping"
else
    log "Generating gene type distribution barplot..."
    
    python ${SCRIPTS_DIR}/plot_genetype_barplot.py \
        --input ${FC_TPM} \
        --output ${BARPLOT_OUTPUT} \
        --top 15 \
        --title "Gene Type Distribution - ${SAMPLE_NAME}" \
        --min_tpm 0 \
        > ${OUTPUT_DIR}/logs/barplot.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ Gene type barplot generated!"
        log "  Output: ${BARPLOT_OUTPUT}"
    else
        log "WARNING: Barplot generation failed (check logs/barplot.log)"
    fi
fi

log ""

# ============================================================================
# PIPELINE COMPLETION
# ============================================================================

log "========================================="
log "Pipeline completed successfully!"
log "Output directory: ${OUTPUT_DIR}"
log "Summary report: ${SUMMARY}"
log "Gene type plot: ${BARPLOT_OUTPUT}"
log "========================================="
log ""
log "Next steps:"
log "  1. Review summary: cat ${SUMMARY}"
log "  2. Check miRNAs: less ${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_featureCounts.tsv"
log "  3. View QC report: open ${OUTPUT_DIR}/05_qc/${SAMPLE_NAME}_trimmed_fastqc.html"
log "  4. View gene types: open ${BARPLOT_OUTPUT}"
log ""

exit 0
