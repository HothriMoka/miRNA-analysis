#!/bin/bash
#SBATCH --job-name=test_emapper
#SBATCH --output=logs/emapper_test_%j.log
#SBATCH --error=logs/emapper_test_%j.err
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=80G
#SBATCH --partition=cpu

################################################################################
# Test script to run EMapper on a single sample and compare with featureCounts
################################################################################

# Note: Using 'set -e' only (not -u) to avoid issues with undefined variables in module loading
set -e

# Usage
if [ $# -ne 2 ]; then
    echo "Usage: $0 <sample_name> <sample_output_directory>"
    echo "Example: $0 204925_S1 /path/to/204925_S1_output"
    exit 1
fi

SAMPLE_NAME="$1"
SAMPLE_OUTPUT_DIR="$2"

# Get script directory
if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Paths
REF_DIR="${SCRIPT_DIR}/references"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
GTF_FILE="${REF_DIR}/annotations/gencode.vM38.annotation.gtf"

# Input BAM
BAM_FILE="${SAMPLE_OUTPUT_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam"

# Output directory
EMAPPER_DIR="${SAMPLE_OUTPUT_DIR}/06_emapper"
mkdir -p "${EMAPPER_DIR}"

echo "========================================"
echo "EMapper Test for ${SAMPLE_NAME}"
echo "========================================"
echo "Sample output: ${SAMPLE_OUTPUT_DIR}"
echo "BAM file: ${BAM_FILE}"
echo "Output dir: ${EMAPPER_DIR}"
echo ""

# Check files exist
if [ ! -f "${BAM_FILE}" ]; then
    echo "ERROR: BAM file not found: ${BAM_FILE}"
    exit 1
fi

if [ ! -f "${GTF_FILE}" ]; then
    echo "ERROR: GTF file not found: ${GTF_FILE}"
    exit 1
fi

# Activate conda environment (EMapper only needs conda, not cluster modules)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activating conda environment..."
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

# Verify conda environment is activated
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "ERROR: Conda environment not activated"
    exit 1
fi

echo "✓ Conda environment: $CONDA_DEFAULT_ENV"
echo "✓ Python: $(which python)"
echo "✓ Python version: $(python --version)"

# Verify EMapper dependencies
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verifying EMapper dependencies..."
python -c "import pyBigWig, numba, pysam, psutil, numpy; print('✓ All EMapper dependencies available')"

if [ $? -ne 0 ]; then
    echo "ERROR: EMapper dependencies not found"
    exit 1
fi

# Step 1: Run EMapper to generate BigWig files
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Step 1: Running EMapper ==="
echo "NOTE: EMapper requires name-sorted BAM. Sorting input BAM by name..."

# Create name-sorted BAM for EMapper
NAME_SORTED_BAM="${EMAPPER_DIR}/${SAMPLE_NAME}_namesorted.bam"
samtools sort -n -@ 16 -o "${NAME_SORTED_BAM}" "${BAM_FILE}"

echo "✓ Name-sorted BAM created: ${NAME_SORTED_BAM}"
echo "Running EMapper EM algorithm..."

python "${SCRIPTS_DIR}/Step_25_EMapper.py" \
    --input_bam "${NAME_SORTED_BAM}" \
    --sample_name "${SAMPLE_NAME}" \
    --output_dir "${EMAPPER_DIR}" \
    --num_threads 16 \
    --split_by_strand yes \
    --mode multi \
    --max_iter 10

if [ $? -eq 0 ]; then
    echo "✓ EMapper completed successfully"
    ls -lh "${EMAPPER_DIR}"/*.bw 2>/dev/null || echo "BigWig files not found (this is OK if mode was uniq)"
    # Clean up name-sorted BAM to save space
    rm -f "${NAME_SORTED_BAM}"
else
    echo "✗ EMapper failed"
    exit 1
fi

# Step 2: Convert BigWig to CPM for miRNA quantification
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Step 2: Converting BigWig to CPM ==="

# Create miRNA-only GTF
MIRNA_GTF="${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_only.gtf"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Extracting miRNA annotations..."
grep -w "gene" "${GTF_FILE}" | grep 'gene_type "miRNA"' > "${MIRNA_GTF}"
MIRNA_COUNT=$(wc -l < "${MIRNA_GTF}")
echo "  Found ${MIRNA_COUNT} miRNA genes in GTF"

# Run bigWig2CPM
python "${SCRIPTS_DIR}/Step_25_bigWig2CPM.py" \
    --stranded no \
    --input_F1R2_bw "${EMAPPER_DIR}/${SAMPLE_NAME}_final_F1R2.bw" \
    --input_F2R1_bw "${EMAPPER_DIR}/${SAMPLE_NAME}_final_F2R1.bw" \
    --gtf "${MIRNA_GTF}" \
    --output "${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv"

if [ $? -eq 0 ]; then
    echo "✓ BigWig to CPM conversion completed"
    echo "  Output: ${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv"
else
    echo "✗ BigWig2CPM failed"
    exit 1
fi

# Step 3: Compare with featureCounts results
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Step 3: Comparison Analysis ==="

# Count miRNAs detected
FC_MIRNA_FILE="${SAMPLE_OUTPUT_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_featureCounts.tsv"
EM_MIRNA_COUNT=$(awk 'NR>1 && $2>0' "${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv" | wc -l)
FC_MIRNA_COUNT=$(awk 'NR>1 && $NF>0' "${FC_MIRNA_FILE}" | wc -l)

echo "========================================"
echo "COMPARISON RESULTS"
echo "========================================"
echo "featureCounts detected: ${FC_MIRNA_COUNT} miRNAs"
echo "EMapper detected:       ${EM_MIRNA_COUNT} miRNAs (with CPM > 0)"
echo ""

# Show top 10 from each method
echo "Top 10 miRNAs by featureCounts (TPM):"
echo "--------------------------------------"
awk 'NR==1 || $NF>0' "${FC_MIRNA_FILE}" | sort -k8 -rn | head -11 | column -t

echo ""
echo "Top 10 miRNAs by EMapper (CPM):"
echo "--------------------------------------"
awk 'NR==1 || $2>0' "${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv" | sort -k2 -rn | head -11 | column -t

echo ""
echo "========================================"
echo "EMapper test completed successfully!"
echo "========================================"
echo "Output files:"
echo "  BigWig files: ${EMAPPER_DIR}/*.bw"
echo "  miRNA CPM:    ${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv"
echo "  miRNA GTF:    ${MIRNA_GTF}"
echo "========================================"
