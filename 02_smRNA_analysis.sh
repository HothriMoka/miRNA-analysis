#!/bin/bash
#SBATCH --job-name=smRNA_analysis
#SBATCH --output=logs/smRNA_%A_%x.log
#SBATCH --error=logs/smRNA_%A_%x.err
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --partition=hmem
#
# smRNA_analysis.sh - Small RNA-seq Analysis Pipeline
# Optimized for Takara SMARTer smRNA-Seq Kit
# Mouse genome (GRCm39, GENCODE M38)
#
# Resource requirements:
#   - Memory: 64GB (for STAR alignment + buffer)
#   - CPUs: 16 (parallel processing, max for cpu partition)
#   - Time: ~1-2 hours per sample
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

# Load conda environment FIRST (contains fixed RSEM with zlib-ng 2.2.5)
if command -v conda &> /dev/null; then
    source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
    conda activate smallrna-tools 2>/dev/null || true
fi

# Load cluster modules (RSEM will come from conda, not cluster)
module load star/2.7.11a-pgsk3s4 subread/2.0.6 fastqc/0.12.1 2>/dev/null || true

# Get script directory - use SLURM_SUBMIT_DIR when run via sbatch, otherwise use script location
if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
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
  --threads INT     Number of threads (default: 16)
  --output-dir DIR  Output directory (default: <sample_name>_output)
  --adapter SEQ     3' adapter sequence (required - set in Run_SmallRNA_Pipeline.sh)

Example:
  $0 Sample1 /path/to/sample.fastq.gz --threads 16 --adapter AGATCGGAAGAGCACACGTCTGAACTCCAGTCA

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
ADAPTER_SEQ=""  # must be set via --adapter

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
        --adapter)
            ADAPTER_SEQ="$2"
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

if [[ -z "${ADAPTER_SEQ}" ]]; then
    echo "ERROR: --adapter is required."
    echo "       Set ADAPTER_SEQUENCE in Run_SmallRNA_Pipeline.sh and run via the orchestrator,"
    echo "       or pass it directly: --adapter AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
    exit 1
fi

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
MIRNA_GTF="${REFS_DIR}/annotations/gencode.vM38.miRNA_only.gtf"
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

if [[ ! -f "${MIRNA_GTF}" ]]; then
    echo "ERROR: miRNA GTF not found: ${MIRNA_GTF}"
    echo "Create it (e.g. grep miRNA references/annotations/gencode.vM38.annotation.gtf > references/annotations/gencode.vM38.miRNA_only.gtf)"
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
# STEP 1: ADAPTER TRIMMING
# ============================================================================

log "=== Step 1: Adapter Trimming ==="

TRIMMED_FQ="${OUTPUT_DIR}/01_trimmed/${SAMPLE_NAME}_trimmed.fq.gz"
TRIM_REPORT="${OUTPUT_DIR}/01_trimmed/${SAMPLE_NAME}_cutadapt_report.txt"

if [[ -f "${TRIMMED_FQ}" ]]; then
    log "Trimmed FASTQ already exists, skipping: ${TRIMMED_FQ}"
else
    log "Running cutadapt (adapter: ${ADAPTER_SEQ})..."
    # -u 3: trim 3 nt from 5' end (TSO artifact for Takara SMARTer; remove if different kit)
    # overlap 10, discard-untrimmed: standard for miRNA; -M 60 allows reads that had partial adapter
    cutadapt \
        -j ${THREADS} \
        -u 3 \
        -a "${ADAPTER_SEQ}" \
        --overlap 10 \
        --discard-untrimmed \
        -m 15 \
        -M 60 \
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
    # STAR index (from 01) was built with full GENCODE GTF; no separate GTF at mapping.
    # Critical for ~22 nt miRNAs: alignIntronMax 1 (no splicing), outFilter*OverLread 0,
    # alignEndsType Local (allows soft-clipping of residual adapter), outSAMmultNmax -1 (RSEM needs all multi-mappers).
    STAR --genomeDir ${STAR_INDEX} \
        --readFilesIn ${TRIMMED_FQ} \
        --readFilesCommand zcat \
        --outFileNamePrefix ${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_ \
        --runThreadN ${THREADS} \
        --outSAMtype SAM \
        --quantMode TranscriptomeSAM \
        --alignIntronMax 1 \
        --alignEndsType Local \
        --alignMatesGapMax 50 \
        --outFilterMultimapNmax 50 \
        --winAnchorMultimapNmax 50 \
        --outSAMmultNmax -1 \
        --outFilterMismatchNmax 1 \
        --outFilterMatchNmin 16 \
        --outFilterScoreMinOverLread 0 \
        --outFilterMatchNminOverLread 0 \
        --sjdbScore 1 \
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
FC_BIOTYPE="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_featureCounts_biotype_QC.tsv"

if [[ -f "${FC_OUT}" ]]; then
    log "featureCounts miRNA output already exists, skipping"
else
    # Run 1: miRNA quantification with miRNA-only GTF (-t exon, coordinates identical to transcript)
    log "Run 1: miRNA quantification (miRNA-only GTF)..."
    featureCounts \
        -a ${MIRNA_GTF} \
        -o ${FC_OUT} \
        -T ${THREADS} \
        -s 0 \
        -g gene_id \
        -t exon \
        -M --fraction \
        ${ALIGNED_BAM} \
        > ${OUTPUT_DIR}/logs/featureCounts.log 2>&1

    if [[ $? -ne 0 ]]; then
        log "✗ ERROR: featureCounts miRNA failed! Check ${OUTPUT_DIR}/logs/featureCounts.log"
        exit 1
    fi
    ASSIGNED=$(grep "Assigned" ${FC_SUMMARY} | cut -f2)
    UNASSIGNED=$(grep "Unassigned_NoFeatures" ${FC_SUMMARY} | cut -f2)
    log "  Assigned to miRNA genes: ${ASSIGNED}"
    log "  Unassigned: ${UNASSIGNED}"

    # Run 2: biotype QC - what are all the reads? (uses full GTF, gene_type as group)
    log "Run 2: biotype QC (full GTF, gene_type)..."
    featureCounts \
        -a ${GENE_GTF} \
        -o ${FC_BIOTYPE} \
        -T ${THREADS} \
        -s 0 \
        -g gene_type \
        -t transcript \
        -M --fraction \
        ${ALIGNED_BAM} \
        > ${OUTPUT_DIR}/logs/featureCounts_biotype.log 2>&1

    if [[ $? -ne 0 ]]; then
        log "⚠ WARNING: featureCounts biotype failed; miRNA counts are OK"
    else
        log "✓ featureCounts complete!"
        # Print biotype breakdown immediately so it appears in every run's log
        log "  RNA biotype breakdown (top 10):"
        sort -t$'\t' -k7 -rn ${FC_BIOTYPE} | \
            grep -v "^#" | \
            awk -F'\t' 'NR>1 && $7>0 {printf "    %-35s %d\n", $1, $7}' | \
            head -10 | tee -a ${LOGFILE}
    fi

    # Run 3: all genes (full GTF) for RNA distribution, gene-type barplot, top genes
    FC_FULL="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_featureCounts_all_genes.tsv"
    log "Run 3: all-gene quantification (full GTF for QC plots)..."
    featureCounts \
        -a ${GENE_GTF} \
        -o ${FC_FULL} \
        -T ${THREADS} \
        -s 0 \
        -g gene_id \
        -t exon \
        -M --fraction \
        ${ALIGNED_BAM} \
        > ${OUTPUT_DIR}/logs/featureCounts_all_genes.log 2>&1

    if [[ $? -ne 0 ]]; then
        log "⚠ WARNING: featureCounts all-gene failed; QC plots will show miRNAs only"
    fi
fi

FC_FULL="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_featureCounts_all_genes.tsv"
FC_FULL_TPM="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_featureCounts_all_genes_TPM.tsv"

# ============================================================================
# STEP 5: QUANTIFICATION WITH RSEM
# ============================================================================

log ""
log "=== Step 5: Quantification with RSEM (EM algorithm) ==="

RSEM_OUT="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_RSEM.genes.results"
RSEM_PREFIX="${OUTPUT_DIR}/03_counts/${SAMPLE_NAME}_RSEM"

# Initialize RSEM success flag
RSEM_SUCCESS=false
TRANSCRIPTOME_BAM="${OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.toTranscriptome.out.bam"

if [[ -f "${RSEM_OUT}" && -s "${RSEM_OUT}" ]]; then
    log "RSEM output already exists and is valid, skipping"
    RSEM_SUCCESS=true
elif [[ ! -f "${TRANSCRIPTOME_BAM}" ]]; then
    log "WARNING: Transcriptome BAM not found (${TRANSCRIPTOME_BAM})"
    log "  STAR may not have generated it. Skipping RSEM."
else
    log "Running RSEM (with conda's fixed zlib-ng - no bgzf bug!)..."
    log "  Using transcriptome BAM: ${TRANSCRIPTOME_BAM}"
    
    rsem-calculate-expression \
        --bam \
        --no-bam-output \
        -p ${THREADS} \
        --seed 12345 \
        ${TRANSCRIPTOME_BAM} \
        ${RSEM_INDEX} \
        ${RSEM_PREFIX} \
        > ${OUTPUT_DIR}/logs/rsem.log 2>&1
    RSEM_EXIT_CODE=$?
    
    if [[ ${RSEM_EXIT_CODE} -eq 0 ]]; then
        log "✓ RSEM complete! (bgzf bug fixed with conda)"
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

# featureCounts all-gene → TPM (for RNA distribution, barplot, top genes - all RNA types)
if [[ -f "${FC_FULL}" ]]; then
    if [[ -f "${FC_FULL_TPM}" ]]; then
        log "featureCounts all-gene TPM already exists, skipping"
    else
        log "Converting featureCounts all-gene to TPM..."
        python ${SCRIPTS_DIR}/Step_15_featureCounts2TPM.py \
            --featureCounts_out ${FC_FULL} \
            --GeneID_meta_table ${GENE_META} \
            --output ${FC_FULL_TPM} \
            > ${OUTPUT_DIR}/logs/fc_all_genes_to_tpm.log 2>&1
        if [[ $? -eq 0 ]]; then
            log "✓ featureCounts all-gene TPM generated!"
        else
            log "⚠ WARNING: featureCounts all-gene TPM conversion failed"
            FC_FULL_TPM=""  # will fall back to FC_TPM for plots
        fi
    fi
else
    FC_FULL_TPM=""  # no all-gene matrix; plots will use miRNA-only FC_TPM
fi

# Use all-gene TPM for QC plots if available; else miRNA-only TPM
PLOT_INPUT="${FC_FULL_TPM:-${FC_TPM}}"

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
    # Temporarily disable pipefail for this complex pipeline
    set +o pipefail
    TOP_MIRNAS=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${RSEM_TPM} | \
        sort -t$'\t' -k5 -nr | head -10 | \
        awk -F'\t' '{printf "  %-20s %10.2f TPM\n", $2, $5}')
    set -o pipefail
    echo "${TOP_MIRNAS}" | tee -a ${LOGFILE}
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
Adapter: ${ADAPTER_SEQ}
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
  - Assigned to miRNA genes: $(grep "Assigned" ${FC_SUMMARY} | cut -f2)
  - Total genes detected: $(awk -F'\t' 'NR>1 && $5>0' ${PLOT_INPUT} | wc -l)

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
        --input ${PLOT_INPUT} \
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
# STEP 10: GENERATE RNA DISTRIBUTION 2-SUBPLOT PLOT
# ============================================================================

log "=== Step 10: Generate RNA Distribution Plot (2 Subplots) ==="

RNA_DIST_OUTPUT="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_RNA_distribution_2subplots"

if [[ -f "${RNA_DIST_OUTPUT}.pdf" ]]; then
    log "RNA distribution plot already exists, skipping"
else
    log "Generating RNA distribution plot (expression-weighted vs count-based)..."
    
    python ${SCRIPTS_DIR}/plot_RNA_distribution_2subplots.py \
        --input ${PLOT_INPUT} \
        --output ${RNA_DIST_OUTPUT} \
        --sample_name ${SAMPLE_NAME} \
        > ${OUTPUT_DIR}/logs/rna_distribution.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ RNA distribution plot generated!"
        log "  PDF: ${RNA_DIST_OUTPUT}.pdf"
        log "  PNG: ${RNA_DIST_OUTPUT}.png"
    else
        log "WARNING: RNA distribution plot failed (check logs/rna_distribution.log)"
    fi
fi

log ""

# ============================================================================
# STEP 11: GENERATE TOP EXPRESSED GENES PLOT
# ============================================================================

log "=== Step 11: Generate Top Expressed Genes Plot ==="

TOP_GENES_PDF="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.pdf"
TOP_GENES_PNG="${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.png"

if [[ -f "${TOP_GENES_PDF}" ]]; then
    log "Top genes plot already exists, skipping"
else
    log "Generating top expressed genes plot..."
    
    python ${SCRIPTS_DIR}/plot_top_expressed_genes.py \
        --input ${PLOT_INPUT} \
        --output_pdf ${TOP_GENES_PDF} \
        --output_png ${TOP_GENES_PNG} \
        --genes_per_type 3 \
        --total_genes 50 \
        --sample_name ${SAMPLE_NAME} \
        > ${OUTPUT_DIR}/logs/top_genes.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "✓ Top expressed genes plot generated!"
        log "  PDF: ${TOP_GENES_PDF}"
        log "  PNG: ${TOP_GENES_PNG}"
    else
        log "WARNING: Top genes plot failed (check logs/top_genes.log)"
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
log "========================================="
log ""
log "Generated Plots:"
log "  - Gene type distribution: ${BARPLOT_OUTPUT}"
log "  - RNA composition (2 subplots): ${RNA_DIST_OUTPUT}.pdf"
log "  - Top expressed genes: ${TOP_GENES_PDF}"
log ""
log "Next steps:"
log "  1. Review summary: cat ${SUMMARY}"
log "  2. Check miRNAs: less ${OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_featureCounts.tsv"
log "  3. View QC report: open ${OUTPUT_DIR}/05_qc/${SAMPLE_NAME}_trimmed_fastqc.html"
log "  4. View plots: open ${OUTPUT_DIR}/04_expression/*.pdf"
log ""

exit 0
