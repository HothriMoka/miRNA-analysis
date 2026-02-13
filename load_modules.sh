#!/bin/bash
#
# load_modules.sh - Load required modules for the pipeline
# Source this file before running the pipeline: source load_modules.sh
#

echo "Loading required modules..."

# Load bioinformatics tools
module load star/2.7.11a-pgsk3s4
module load rsem/1.3.3
module load subread/2.0.6
module load fastqc/0.12.1
module load samtools/1.17-xtpk2gu

# Activate conda environment for cutadapt and Python packages
conda activate smallrna-tools 2>/dev/null || echo "Warning: smallrna-tools conda env not found, trying to install packages..."

# Check if pandas is available
if ! python -c "import pandas" 2>/dev/null; then
    echo "Installing pandas and numpy..."
    pip install --user pandas numpy 2>/dev/null || echo "Warning: Could not install pandas/numpy"
fi

echo ""
echo "Modules loaded successfully!"
echo ""
echo "Loaded tools:"
which STAR
which rsem-calculate-expression
which featureCounts
which fastqc
which samtools
which cutadapt
echo ""
echo "Ready to run pipeline!"
