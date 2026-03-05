#!/bin/bash
#SBATCH --job-name=emapper_all
#SBATCH --output=logs/emapper_all_%j.log
#SBATCH --error=logs/emapper_all_%j.err
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --partition=hmem

################################################################################
# Run EMapper on all samples in mouse_miRNA directory
################################################################################

set -euo pipefail

# Get script directory
if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Paths
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
REF_DIR="${SCRIPT_DIR}/references"
GTF_FILE="${REF_DIR}/annotations/gencode.vM38.annotation.gtf"
OUTPUT_BASE="${OUTPUT_BASE:-}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

if [ -z "${OUTPUT_BASE}" ]; then
    echo "ERROR: OUTPUT_BASE is not set."
    echo "       Please set OUTPUT_BASE before running this script,"
    echo "       or run it via Run_SmallRNA_Pipeline.sh which configures it for you."
    exit 1
fi

echo "========================================"
echo "Running EMapper on All Samples"
echo "========================================"
echo "Output directory: ${OUTPUT_BASE}"
echo "Threads: ${THREADS}"
echo ""

# Activate conda environment
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activating conda environment..."
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "✓ Conda environment: $CONDA_DEFAULT_ENV"
echo "✓ Python: $(which python)"

# Verify dependencies
python -c "import pyBigWig, numba, pysam, psutil, numpy; print('✓ All dependencies available')"

# Find all sample output directories
SAMPLE_DIRS=$(find ${OUTPUT_BASE} -maxdepth 1 -type d -name "*_output" | sort)
TOTAL_SAMPLES=$(echo "${SAMPLE_DIRS}" | wc -l)

echo ""
echo "Found ${TOTAL_SAMPLES} sample directories"
echo ""

# Counter
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SAMPLES=()

# Process each sample
for SAMPLE_DIR in ${SAMPLE_DIRS}; do
    SAMPLE_NAME=$(basename ${SAMPLE_DIR} _output)
    
    echo "========================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: ${SAMPLE_NAME}"
    echo "========================================"
    
    # Paths
    BAM_FILE="${SAMPLE_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam"
    EMAPPER_DIR="${SAMPLE_DIR}/06_emapper"
    NAME_SORTED_BAM="${EMAPPER_DIR}/${SAMPLE_NAME}_namesorted.bam"
    
    # Check if BAM exists
    if [ ! -f "${BAM_FILE}" ]; then
        echo "✗ ERROR: BAM file not found: ${BAM_FILE}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SAMPLES+=("${SAMPLE_NAME}")
        continue
    fi
    
    # Create output directory
    mkdir -p "${EMAPPER_DIR}"
    
    # Clean up any existing incomplete run
    echo "  Cleaning up previous EMapper run..."
    rm -f "${EMAPPER_DIR}"/*.bw
    rm -f "${EMAPPER_DIR}"/*_EMapper.log
    
    # Step 1: Sort BAM by name
    echo "  [1/2] Sorting BAM by name..."
    if [ -f "${NAME_SORTED_BAM}" ]; then
        echo "    Name-sorted BAM already exists, removing..."
        rm -f "${NAME_SORTED_BAM}"
    fi
    
    samtools sort -n -@ ${THREADS} -o "${NAME_SORTED_BAM}" "${BAM_FILE}"
    
    if [ $? -ne 0 ]; then
        echo "✗ ERROR: BAM sorting failed"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SAMPLES+=("${SAMPLE_NAME}")
        continue
    fi
    
    echo "    ✓ Name-sorted BAM created ($(du -h ${NAME_SORTED_BAM} | cut -f1))"
    
    # Step 2: Run EMapper
    echo "  [2/2] Running EMapper EM algorithm..."
    
    python "${SCRIPTS_DIR}/Step_25_EMapper.py" \
        --input_bam "${NAME_SORTED_BAM}" \
        --sample_name "${SAMPLE_NAME}" \
        --output_dir "${EMAPPER_DIR}" \
        --num_threads ${THREADS} \
        --split_by_strand yes \
        --mode multi \
        --max_iter 10
    
    EMAPPER_EXIT=$?
    
    if [ ${EMAPPER_EXIT} -eq 0 ]; then
        # Check if BigWig files were created
        BW_COUNT=$(ls "${EMAPPER_DIR}"/*.bw 2>/dev/null | wc -l)
        
        if [ ${BW_COUNT} -gt 0 ]; then
            echo "  ✓ EMapper completed successfully!"
            echo "    Generated ${BW_COUNT} BigWig files:"
            ls -lh "${EMAPPER_DIR}"/*.bw
            
            # Clean up name-sorted BAM to save space
            echo "    Cleaning up temporary files..."
            rm -f "${NAME_SORTED_BAM}"
            
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "  ✗ ERROR: EMapper completed but no BigWig files generated"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_SAMPLES+=("${SAMPLE_NAME}")
        fi
    else
        echo "  ✗ ERROR: EMapper failed with exit code ${EMAPPER_EXIT}"
        echo "    Check log: ${EMAPPER_DIR}/${SAMPLE_NAME}_EMapper.log"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SAMPLES+=("${SAMPLE_NAME}")
    fi
    
    echo ""
done

# Final summary
echo "========================================"
echo "BATCH PROCESSING COMPLETE"
echo "========================================"
echo "Total samples:  ${TOTAL_SAMPLES}"
echo "Successful:     ${SUCCESS_COUNT}"
echo "Failed:         ${FAILED_COUNT}"
echo ""

if [ ${FAILED_COUNT} -gt 0 ]; then
    echo "Failed samples:"
    for sample in "${FAILED_SAMPLES[@]}"; do
        echo "  - ${sample}"
    done
    echo ""
fi

echo "BigWig files location: ${OUTPUT_BASE}/*/06_emapper/*.bw"
echo ""

# Exit with error if any failed
if [ ${FAILED_COUNT} -gt 0 ]; then
    exit 1
else
    echo "✓ All samples processed successfully!"
    exit 0
fi
