#!/bin/bash
# Test RSEM with conda's fixed zlib-ng 2.2.5

echo "=========================================="
echo "Testing RSEM with Conda (Fixed zlib-ng)"
echo "=========================================="

# Activate conda environment ONLY (no cluster modules)
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "✓ Conda environment: $CONDA_DEFAULT_ENV"
echo "✓ RSEM: $(which rsem-calculate-expression)"
echo "✓ samtools: $(which samtools)"
echo ""

# Check versions
rsem-calculate-expression --version
samtools --version | head -2
echo ""

# Check zlib linkage
echo "Checking library linkages:"
ldd $(which rsem-calculate-expression) | grep -E 'libz\.so|libhts'
ldd $(which samtools) | grep -E 'libz\.so'
echo ""

# Test data
BAM="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204913_S13_output/02_aligned/204913_S13_Aligned.sortedByCoord.out.bam"
REF="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/indices/RSEM/RSEM_REF_MM39"
OUTPUT_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/test_rsem_conda_fixed"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Running RSEM test..."
echo "=========================================="
echo "Input BAM: $BAM"
echo "Reference: $REF"
echo "Output: $OUTPUT_DIR"
echo ""

# Run RSEM
rsem-calculate-expression \
    --bam \
    --no-bam-output \
    --seed 12345 \
    -p 8 \
    "$BAM" \
    "$REF" \
    "${OUTPUT_DIR}/test" \
    2>&1 | tee "${OUTPUT_DIR}/rsem_full.log"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓✓✓ SUCCESS! RSEM WORKS! ✓✓✓"
    echo "=========================================="
    echo ""
    echo "Output files:"
    ls -lh "${OUTPUT_DIR}"/test.genes.results
    echo ""
    echo "Gene count:"
    wc -l "${OUTPUT_DIR}"/test.genes.results
    echo ""
    echo "miRNA count:"
    grep 'gene_type "miRNA"' /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/annotations/gencode.vM38.annotation.gtf | awk '$3=="gene"' | awk '{print $10}' | tr -d '";' > /tmp/mirna_ids.txt
    grep -f /tmp/mirna_ids.txt "${OUTPUT_DIR}"/test.genes.results | awk '$7>0' | wc -l
else
    echo "✗ FAILED (exit code: $EXIT_CODE)"
    echo "=========================================="
    echo ""
    echo "Check error log: ${OUTPUT_DIR}/rsem_full.log"
    echo "Last 20 lines:"
    tail -20 "${OUTPUT_DIR}/rsem_full.log"
fi
