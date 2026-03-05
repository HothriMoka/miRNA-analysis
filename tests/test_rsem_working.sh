#!/bin/bash
# Test RSEM with conda - using STAR transcriptome BAM

source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "Testing RSEM with conda (FIXED zlib-ng!)"
echo "=========================================="

# First, run STAR to generate transcriptome BAM
FASTQ="/home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/260115_VH00409_52_AAHJGFTM5/204913_S13_R1_001.fastq.gz"
GENOME_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/indices/STAR"
OUTPUT="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/test_rsem_transcriptome"
REF="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references/indices/RSEM/RSEM_REF_MM39"

mkdir -p $OUTPUT

# Load STAR module
module load star/2.7.11a-pgsk3s4

echo "Step 1: STAR alignment with transcriptome output..."
STAR --runThreadN 8 \
     --genomeDir $GENOME_DIR \
     --readFilesIn $FASTQ \
     --readFilesCommand zcat \
     --outFileNamePrefix ${OUTPUT}/test_ \
     --outSAMtype BAM Unsorted \
     --quantMode TranscriptomeSAM \
     --outSAMunmapped Within \
     --outFilterMismatchNmax 2

if [ $? -eq 0 ]; then
    echo "✓ STAR completed"
    ls -lh ${OUTPUT}/*toTranscriptome.out.bam
else
    echo "✗ STAR failed"
    exit 1
fi

echo ""
echo "Step 2: Run RSEM on transcriptome BAM..."
rsem-calculate-expression \
    --bam \
    --no-bam-output \
    -p 8 \
    ${OUTPUT}/test_Aligned.toTranscriptome.out.bam \
    $REF \
    ${OUTPUT}/rsem_output

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓✓✓ RSEM WORKS! bgzf bug is FIXED! ✓✓✓"
    echo "=========================================="
    echo ""
    wc -l ${OUTPUT}/rsem_output.genes.results
else
    echo "✗ RSEM failed (exit code: $EXIT_CODE)"
fi
