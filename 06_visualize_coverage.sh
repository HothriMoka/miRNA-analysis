#!/bin/bash
#SBATCH --job-name=coverage_viz
#SBATCH --output=logs/coverage_viz_%j.log
#SBATCH --error=logs/coverage_viz_%j.err
#SBATCH --time=8:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --partition=hmem

################################################################################
# Step 26: Generate Coverage Density Plots from EMapper BigWig Files
#
# This script:
# 1. Creates BED files for different RNA types from GTF
# 2. Generates density plots showing coverage over RNA types
# 3. Generates meta-gene profile plots
################################################################################

set -euo pipefail

# Get script directory
if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "${SCRIPT_DIR}"

# Paths
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
REF_DIR="${SCRIPT_DIR}/references"
GTF_FILE="${REF_DIR}/annotations/gencode.vM38.annotation.gtf"
BED_DIR="${REF_DIR}/bed_files"
OUTPUT_BASE="${OUTPUT_BASE:-}"

if [ -z "${OUTPUT_BASE}" ]; then
    echo "ERROR: OUTPUT_BASE is not set."
    echo "       Please set OUTPUT_BASE before running this script,"
    echo "       or run it via Run_SmallRNA_Pipeline.sh which configures it for you."
    exit 1
fi

# deepTools scripts (mouse-specific versions without hardcoded paths)
DENSITY_SCRIPT="${SCRIPTS_DIR}/density_plot_over_RNA_types.sh"
METAGENE_SCRIPT="${SCRIPTS_DIR}/metagene_plot.sh"

echo "========================================"
echo "Coverage Visualization (Step 26)"
echo "========================================"
echo "Output base: ${OUTPUT_BASE}"
echo "BED directory: ${BED_DIR}"
echo ""

# Load conda environment for Python dependencies
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading conda environment..."
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "✓ Conda environment: $CONDA_DEFAULT_ENV"
echo ""

# Step 1: Create BED files for RNA types if they don't exist
echo "=== Step 1: Creating BED Files for RNA Types ==="
echo ""

if [ ! -d "${BED_DIR}" ] || [ -z "$(ls -A ${BED_DIR}/*.bed 2>/dev/null)" ]; then
    echo "Generating BED files from GTF..."
    
    python ${SCRIPTS_DIR}/create_rna_type_beds.py \
        --gtf ${GTF_FILE} \
        --output_dir ${BED_DIR} \
        --rna_types miRNA tRNA rRNA snoRNA snRNA protein_coding lncRNA
    
    echo ""
    echo "✓ BED files created!"
else
    echo "✓ BED files already exist"
    ls -lh ${BED_DIR}/*.bed
fi

echo ""

# Check for deepTools
if ! command -v computeMatrix &> /dev/null; then
    echo "ERROR: deepTools not found. Installing..."
    pip install deeptools
fi

echo "✓ deepTools available: $(computeMatrix --version 2>&1 | head -1)"
echo ""

# Step 2: Process each sample
echo "=== Step 2: Generating Coverage Plots for Each Sample ==="
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

cd "${OUTPUT_BASE}"

for dir in *_output; do
    SAMPLE_NAME=$(basename "$dir" _output)
    SAMPLE_DIR="${OUTPUT_BASE}/${dir}"
    
    echo "========================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${SAMPLE_NAME}"
    echo "========================================"
    
    # Check if BigWig files exist
    BIGWIG_UNSTRANDED="${SAMPLE_DIR}/06_emapper/${SAMPLE_NAME}_final_unstranded.bw"
    
    if [ ! -f "${BIGWIG_UNSTRANDED}" ]; then
        echo "  ✗ BigWig not found: ${BIGWIG_UNSTRANDED}"
        echo "  Skipping visualization for this sample"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    echo "  ✓ Found BigWig: $(du -h ${BIGWIG_UNSTRANDED} | cut -f1)"
    
    # Create visualization output directory
    VIZ_DIR="${SAMPLE_DIR}/07_coverage_plots"
    mkdir -p "${VIZ_DIR}"
    
    # Prepare BED file list and labels for miRNA-focused analysis
    BED_FILES="[${BED_DIR}/mm39_miRNA.bed,${BED_DIR}/mm39_tRNA.bed,${BED_DIR}/mm39_rRNA.bed,${BED_DIR}/mm39_protein_coding.bed,${BED_DIR}/mm39_lncRNA.bed]"
    BED_LABELS="[miRNA,tRNA,rRNA,protein_coding,lncRNA]"
    
    # Generate density plot over RNA types
    echo "  [1/2] Generating RNA type density plot..."
    
    if [ -f "${DENSITY_SCRIPT}" ]; then
        bash ${DENSITY_SCRIPT} \
            --input_bw_file "${BIGWIG_UNSTRANDED}" \
            --input_bed_files "${BED_FILES}" \
            --input_bed_labels "${BED_LABELS}" \
            --output_dir "${VIZ_DIR}" \
            --random_tested_row_num_per_bed 500 \
            > ${VIZ_DIR}/density_plot.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "    ✓ RNA type density plot complete"
        else
            echo "    ✗ RNA type density plot failed (check ${VIZ_DIR}/density_plot.log)"
        fi
    else
        echo "    ⚠ Density plot script not found, skipping"
    fi
    
    # Generate meta-gene profile plot
    echo "  [2/2] Generating meta-gene profile plot..."
    
    if [ -f "${METAGENE_SCRIPT}" ]; then
        bash ${METAGENE_SCRIPT} \
            --input_bw_file "${BIGWIG_UNSTRANDED}" \
            --input_bed_files "${BED_FILES}" \
            --input_bed_labels "${BED_LABELS}" \
            --output_dir "${VIZ_DIR}" \
            --random_tested_row_num_per_bed 500 \
            > ${VIZ_DIR}/metagene_plot.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "    ✓ Meta-gene profile plot complete"
        else
            echo "    ✗ Meta-gene profile failed (check ${VIZ_DIR}/metagene_plot.log)"
        fi
    else
        echo "    ⚠ Meta-gene script not found, skipping"
    fi
    
    # Check if plots were generated
    PLOT_COUNT=$(ls ${VIZ_DIR}/*.png 2>/dev/null | wc -l)
    
    if [ ${PLOT_COUNT} -gt 0 ]; then
        echo "  ✓ Generated ${PLOT_COUNT} plot(s)"
        ls -lh ${VIZ_DIR}/*.png
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "  ✗ No plots generated"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    echo ""
done

# Final summary
echo "========================================"
echo "COVERAGE VISUALIZATION COMPLETE"
echo "========================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
echo ""
echo "Processed: ${SUCCESS_COUNT} samples"
echo "Skipped: ${SKIPPED_COUNT} samples (no BigWig)"
echo "Failed: ${FAILED_COUNT} samples"
echo ""
echo "Output locations:"
echo "  Plots: ${OUTPUT_BASE}/*/07_coverage_plots/*.png"
echo "  Logs:  ${OUTPUT_BASE}/*/07_coverage_plots/*.log"
echo ""

if [ ${FAILED_COUNT} -gt 0 ]; then
    echo "⚠ Some samples failed. Check logs in 07_coverage_plots/"
    exit 1
else
    echo "✓ All samples processed successfully!"
    exit 0
fi
