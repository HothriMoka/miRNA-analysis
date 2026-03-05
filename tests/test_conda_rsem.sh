#!/bin/bash
# Test if RSEM works with conda environment's pysam/htslib

echo "=========================================="
echo "Testing RSEM with Conda Environment"
echo "=========================================="

# Activate conda environment (has pysam with embedded htslib)
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "Environment: $CONDA_DEFAULT_ENV"
echo "Python: $(which python)"
echo ""

# Load RSEM module (but don't load samtools - use conda's instead)
module load rsem/1.3.3

echo "RSEM: $(which rsem-calculate-expression)"
echo ""

# Test data
BAM="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204913_S13_output/02_aligned/204913_S13_Aligned.sortedByCoord.out.bam"
REF="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/indices/RSEM/RSEM_REF_MM39"
OUTPUT_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/test_rsem_conda"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Running RSEM with conda environment..."
echo "=========================================="
echo "This uses pysam's built-in htslib instead of cluster samtools"
echo ""

# Check which samtools/libraries will be used
echo "Library paths that will be checked:"
python -c "import sys; print('\n'.join(sys.path))" | head -10
echo ""

# Run RSEM with timeout
timeout 60s rsem-calculate-expression \
    --bam \
    --no-bam-output \
    --seed 12345 \
    -p 8 \
    "$BAM" \
    "$REF" \
    "${OUTPUT_DIR}/test" \
    > "${OUTPUT_DIR}/stdout.log" 2> "${OUTPUT_DIR}/stderr.log"

EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ SUCCESS! RSEM completed!"
    echo "=========================================="
    echo ""
    echo "Output files:"
    ls -lh "${OUTPUT_DIR}"/test.genes.results 2>/dev/null || echo "No output file"
    echo ""
    echo "Gene count:"
    wc -l "${OUTPUT_DIR}"/test.genes.results 2>/dev/null || echo "No results"
elif [ $EXIT_CODE -eq 124 ]; then
    echo "✗ TIMEOUT - RSEM took >60 seconds"
    echo "=========================================="
else
    echo "✗ FAILED (exit code: $EXIT_CODE)"
    echo "=========================================="
    echo ""
    echo "Error log:"
    cat "${OUTPUT_DIR}/stderr.log"
fi

echo ""
echo "Full logs available in: $OUTPUT_DIR"
