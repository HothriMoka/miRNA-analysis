#!/bin/bash
# Test different samtools versions with RSEM

echo "Testing samtools versions for bgzf bug..."
echo "=========================================="

# Test data
BAM="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204913_S13_output/02_aligned/204913_S13_Aligned.sortedByCoord.out.bam"
REF="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/indices/RSEM/RSEM_REF_MM39"
OUTPUT_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/test_samtools"

mkdir -p "$OUTPUT_DIR"

# Test each version
for version in "1.16.1-34ypzt2" "1.17-xtpk2gu" "1.19.2-tp4qbgg"; do
    echo ""
    echo "=========================================="
    echo "Testing samtools/${version}"
    echo "=========================================="
    
    # Load modules
    module purge
    module load rsem/1.3.3
    module load samtools/${version}
    
    echo "Samtools: $(which samtools)"
    samtools --version | head -3
    
    # Test RSEM
    echo "Running RSEM test..."
    OUTPUT="${OUTPUT_DIR}/rsem_${version}"
    mkdir -p "$OUTPUT"
    
    # Run with timeout (kill after 30 seconds if hangs)
    timeout 30s rsem-calculate-expression \
        --bam \
        --no-bam-output \
        --seed 12345 \
        -p 4 \
        "$BAM" \
        "$REF" \
        "${OUTPUT}/test" \
        > "${OUTPUT}/stdout.log" 2> "${OUTPUT}/stderr.log"
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ SUCCESS with samtools ${version}!"
        echo "  Check output: ${OUTPUT}/test.genes.results"
    elif [ $EXIT_CODE -eq 124 ]; then
        echo "✗ TIMEOUT with samtools ${version}"
    else
        echo "✗ FAILED with samtools ${version} (exit code: $EXIT_CODE)"
        echo "  Error log:"
        tail -5 "${OUTPUT}/stderr.log"
    fi
done

echo ""
echo "=========================================="
echo "Test complete!"
echo "Results in: $OUTPUT_DIR"
echo "=========================================="
