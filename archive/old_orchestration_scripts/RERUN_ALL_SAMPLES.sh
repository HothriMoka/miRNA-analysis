#!/bin/bash
################################################################################
# Rerun Complete Pipeline on All Samples
# 
# This script submits individual SLURM jobs for each sample that needs
# re-processing. Uses the fixed pipeline with conda RSEM and generates
# transcriptome BAMs.
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Paths
FASTQ_DIR="/home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/260115_VH00409_52_AAHJGFTM5"
OUTPUT_BASE="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA"
ANALYSIS_SCRIPT="${SCRIPT_DIR}/02_smRNA_analysis.sh"

echo "========================================================================"
echo "Mouse Small RNA-seq Pipeline - Complete Reprocessing"
echo "========================================================================"
echo "FASTQ directory: ${FASTQ_DIR}"
echo "Output directory: ${OUTPUT_BASE}"
echo "Pipeline script: ${ANALYSIS_SCRIPT}"
echo ""

# Check if analysis script exists
if [ ! -f "${ANALYSIS_SCRIPT}" ]; then
    echo "ERROR: Analysis script not found: ${ANALYSIS_SCRIPT}"
    exit 1
fi

# Find all FASTQ files (R1 only)
FASTQ_FILES=(${FASTQ_DIR}/*_R1_001.fastq.gz)

if [ ${#FASTQ_FILES[@]} -eq 0 ]; then
    echo "ERROR: No FASTQ files found in ${FASTQ_DIR}"
    exit 1
fi

echo "Found ${#FASTQ_FILES[@]} FASTQ files"
echo ""

# List of samples that need reprocessing (all except 204913_S13 which is complete)
SAMPLES_TO_SKIP=("204913_S13")

# Job tracking
SUBMITTED_COUNT=0
SKIPPED_COUNT=0
JOB_IDS=()

echo "========================================================================"
echo "Submitting Jobs"
echo "========================================================================"

for FASTQ in "${FASTQ_FILES[@]}"; do
    # Extract sample name
    SAMPLE_NAME=$(basename ${FASTQ} | sed 's/_R1_001.fastq.gz$//')
    
    # Check if we should skip this sample
    SKIP=false
    for SKIP_SAMPLE in "${SAMPLES_TO_SKIP[@]}"; do
        if [ "${SAMPLE_NAME}" == "${SKIP_SAMPLE}" ]; then
            SKIP=true
            break
        fi
    done
    
    if [ "$SKIP" = true ]; then
        echo "[$((SUBMITTED_COUNT + SKIPPED_COUNT + 1))] Skipping: ${SAMPLE_NAME} (already complete)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Submit job
    echo "[$((SUBMITTED_COUNT + 1))] Submitting: ${SAMPLE_NAME}"
    JOB_ID=$(sbatch --parsable \
        --output="${OUTPUT_BASE}/logs/smRNA_rerun_${SAMPLE_NAME}_%j.log" \
        --error="${OUTPUT_BASE}/logs/smRNA_rerun_${SAMPLE_NAME}_%j.err" \
        "${ANALYSIS_SCRIPT}" \
        "${SAMPLE_NAME}" \
        "${FASTQ}" \
        --threads 8 \
        --output-dir "${OUTPUT_BASE}/${SAMPLE_NAME}_output")
    
    echo "    Job ID: ${JOB_ID}"
    JOB_IDS+=("${JOB_ID}")
    SUBMITTED_COUNT=$((SUBMITTED_COUNT + 1))
done

echo ""
echo "========================================================================"
echo "Submission Complete!"
echo "========================================================================"
echo "Submitted: ${SUBMITTED_COUNT} samples"
echo "Skipped: ${SKIPPED_COUNT} samples (already complete)"
echo "Total: $((SUBMITTED_COUNT + SKIPPED_COUNT)) samples"
echo ""
echo "Job IDs: ${JOB_IDS[@]}"
echo ""
echo "========================================================================"
echo "Monitoring Commands"
echo "========================================================================"
echo ""
echo "Check job status:"
echo "  squeue -u \$USER"
echo ""
echo "Count running jobs:"
echo "  squeue -u \$USER -t RUNNING | wc -l"
echo ""
echo "Count completed jobs:"
echo "  sacct -u \$USER --starttime today --format=JobID,State | grep COMPLETED | wc -l"
echo ""
echo "Check specific sample log:"
echo "  tail -f ${OUTPUT_BASE}/logs/smRNA_rerun_SAMPLE_NAME_JOBID.log"
echo ""
echo "Monitor first few jobs:"
for i in {0..2}; do
    if [ $i -lt ${#JOB_IDS[@]} ]; then
        echo "  tail -f ${OUTPUT_BASE}/logs/smRNA_rerun_*_${JOB_IDS[$i]}.log"
    fi
done
echo ""
echo "Check RSEM results generated:"
echo "  ls ${OUTPUT_BASE}/*/03_counts/*_RSEM.genes.results | wc -l"
echo ""
echo "Expected completion time: ~2-3 hours (all running in parallel)"
echo "========================================================================"

# Save job list
JOB_LIST_FILE="${OUTPUT_BASE}/rerun_job_list_$(date +%Y%m%d_%H%M%S).txt"
printf "%s\n" "${JOB_IDS[@]}" > "${JOB_LIST_FILE}"
echo ""
echo "Job list saved to: ${JOB_LIST_FILE}"
echo ""
