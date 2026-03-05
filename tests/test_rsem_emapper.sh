#!/bin/bash
#SBATCH --job-name=test_rsem_emapper
#SBATCH --output=logs/test_rsem_emapper_%j.log
#SBATCH --error=logs/test_rsem_emapper_%j.err
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --partition=cpu
#
# Test RSEM (conda with fixed zlib) and EMapper on a single sample
#
# Usage: sbatch test_rsem_emapper.sh
#

set -e

# Get script directory - use SLURM_SUBMIT_DIR when run via sbatch
if [ -n "${SLURM_SUBMIT_DIR}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "${SCRIPT_DIR}"

# Test data directory
DATA_DIR="/home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/260115_VH00409_52_AAHJGFTM5"
OUTPUT_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA"

# Pick first sample
FASTQ_FILE=$(ls ${DATA_DIR}/*.fastq.gz | head -n 1)
SAMPLE_NAME=$(basename ${FASTQ_FILE} .fastq.gz | sed 's/_R1.*//')

echo "===================================="
echo "Testing RSEM + EMapper"
echo "===================================="
echo "Sample: ${SAMPLE_NAME}"
echo "Input FASTQ: ${FASTQ_FILE}"
echo "Output: ${OUTPUT_DIR}/${SAMPLE_NAME}_output"
echo "===================================="
echo ""

# Run pipeline
bash ${SCRIPT_DIR}/02_smRNA_analysis.sh \
    ${SAMPLE_NAME} \
    ${FASTQ_FILE} \
    --threads 8 \
    --output-dir ${OUTPUT_DIR}/${SAMPLE_NAME}_output

echo ""
echo "===================================="
echo "Test complete!"
echo "===================================="
echo ""
echo "Check results in: ${OUTPUT_DIR}/${SAMPLE_NAME}_output"
echo ""
echo "Key files to check:"
echo "  - 02_aligned/*_Aligned.toTranscriptome.out.bam (for RSEM)"
echo "  - 03_quantification/rsem/*genes.results (RSEM output)"
echo "  - 05_coverage/*_coverage.bw (EMapper BigWig)"
echo "  - logs/rsem.log (RSEM log)"
echo "  - logs/emapper.log (EMapper log)"
echo ""
