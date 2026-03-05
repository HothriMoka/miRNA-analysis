#!/bin/bash
################################################################################
# Master Script: Run Complete Small RNA-seq Pipeline
################################################################################
# This script runs the entire pipeline on all samples in sequence:
#   1. Build mouse genome references (GRCm39)
#   2. Re-run RSEM quantification on all samples (fixes bgzf bug)
#   3. Run EMapper to generate BigWig coverage files
#
# Usage:
#   bash RUN_FULL_PIPELINE.sh
#   OR
#   sbatch RUN_FULL_PIPELINE.sh --dependency
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "========================================"
echo "Mouse Small RNA-seq Pipeline"
echo "Complete Analysis Workflow"
echo "========================================"
echo "Pipeline directory: ${SCRIPT_DIR}"
echo "Output directory: /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA"
echo ""

# Step 1: Check if references are built
echo "=== Step 1: Checking References ==="
if [ -f "references/indices/STAR/SAindex" ] && [ -f "references/indices/RSEM/RSEM_REF_MM39.grp" ]; then
    echo "✓ References already built"
else
    echo "References not found. Submitting reference building job..."
    REF_JOB=$(sbatch --parsable 01_prepare_mouse_references.sh)
    echo "✓ Reference building job submitted: ${REF_JOB}"
    echo "  Monitor with: squeue -j ${REF_JOB}"
    echo "  Wait for completion before proceeding to next step"
    echo ""
    echo "Once complete, run:"
    echo "  sbatch 04_rerun_rsem_all_samples.sh"
    exit 0
fi

# Step 2: Re-run RSEM for all samples
echo ""
echo "=== Step 2: Submitting RSEM Re-run Job ==="
RSEM_JOB=$(sbatch --parsable 04_rerun_rsem_all_samples.sh)
echo "✓ RSEM re-run job submitted: ${RSEM_JOB}"
echo "  This will process 34 samples (~12-24 hours)"
echo "  Monitor with: squeue -j ${RSEM_JOB}"
echo "  Check log: tail -f logs/rsem_rerun_all_${RSEM_JOB}.log"

# Step 3: Run EMapper (with dependency on RSEM)
echo ""
echo "=== Step 3: Submitting EMapper Job (depends on RSEM) ==="
EMAPPER_JOB=$(sbatch --parsable --dependency=afterok:${RSEM_JOB} 05_run_emapper_all_samples.sh)
echo "✓ EMapper job submitted: ${EMAPPER_JOB}"
echo "  Will start after RSEM completes successfully"
echo "  Monitor with: squeue -j ${EMAPPER_JOB}"
echo "  Check log: tail -f logs/emapper_all_${EMAPPER_JOB}.log"

# Summary
echo ""
echo "========================================"
echo "Pipeline Jobs Submitted"
echo "========================================"
echo "Job Chain:"
echo "  1. RSEM Re-run:  ${RSEM_JOB} (running)"
echo "  2. EMapper:      ${EMAPPER_JOB} (pending, depends on RSEM)"
echo ""
echo "Monitor all jobs: squeue -u \$USER"
echo ""
echo "Expected completion time:"
echo "  - RSEM:    12-24 hours (34 samples)"
echo "  - EMapper: 6-12 hours (34 samples)"
echo "  - Total:   ~18-36 hours"
echo ""
echo "Final outputs will be in:"
echo "  /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/03_counts/*_RSEM.genes.results"
echo "  /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/04_expression/*_RSEM_TPM.tsv"
echo "  /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/04_expression/*_miRNAs_only_RSEM.tsv"
echo "  /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/06_emapper/*.bw"
echo "========================================"
