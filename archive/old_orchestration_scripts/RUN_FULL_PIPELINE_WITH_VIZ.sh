#!/bin/bash

################################################################################
# Complete Pipeline: RSEM → EMapper → Coverage Visualization
#
# This script submits all three stages with job dependencies:
#   1. RSEM quantification (04_rerun_rsem_all_samples.sh)
#   2. EMapper coverage (05_run_emapper_all_samples.sh)  
#   3. Coverage visualization (06_visualize_coverage.sh)
################################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Create logs directory
mkdir -p logs

echo "========================================"
echo "SUBMITTING FULL PIPELINE"
echo "========================================"
echo "Date: $(date)"
echo "Directory: ${SCRIPT_DIR}"
echo ""

# Stage 1: Submit RSEM job
echo "[1/3] Submitting RSEM quantification..."
RSEM_JOB=$(sbatch --parsable 04_rerun_rsem_all_samples.sh)
echo "  Job ID: ${RSEM_JOB}"
echo ""

# Stage 2: Submit EMapper (depends on RSEM)
echo "[2/3] Submitting EMapper (after RSEM)..."
EMAPPER_JOB=$(sbatch --parsable --dependency=afterok:${RSEM_JOB} 05_run_emapper_all_samples.sh)
echo "  Job ID: ${EMAPPER_JOB}"
echo "  Dependency: afterok:${RSEM_JOB}"
echo ""

# Stage 3: Submit Coverage Visualization (depends on EMapper)
echo "[3/3] Submitting coverage visualization (after EMapper)..."
VIZ_JOB=$(sbatch --parsable --dependency=afterok:${EMAPPER_JOB} 06_visualize_coverage.sh)
echo "  Job ID: ${VIZ_JOB}"
echo "  Dependency: afterok:${EMAPPER_JOB}"
echo ""

echo "========================================"
echo "PIPELINE SUBMITTED SUCCESSFULLY"
echo "========================================"
echo ""
echo "Job Chain:"
echo "  1. RSEM:          ${RSEM_JOB}"
echo "  2. EMapper:       ${EMAPPER_JOB} (after ${RSEM_JOB})"
echo "  3. Visualization: ${VIZ_JOB} (after ${EMAPPER_JOB})"
echo ""
echo "Monitor with:"
echo "  squeue -u \$USER"
echo "  sacct -j ${RSEM_JOB},${EMAPPER_JOB},${VIZ_JOB} --format=JobID,JobName,State,Elapsed,MaxRSS"
echo ""
echo "Logs:"
echo "  RSEM:    logs/rsem_rerun_all_${RSEM_JOB}.log"
echo "  EMapper: logs/emapper_all_${EMAPPER_JOB}.log"
echo "  Viz:     logs/coverage_viz_${VIZ_JOB}.log"
echo ""
