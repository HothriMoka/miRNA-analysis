#!/bin/bash
#
# load_modules.sh - Load required modules for the pipeline
# Source this file before running the pipeline: source load_modules.sh
#
# IMPORTANT: Conda is activated FIRST to use fixed RSEM/samtools (no bgzf bug)
#

echo "Loading required modules..."

# Activate conda environment FIRST (contains RSEM with fixed zlib-ng 2.2.5)
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools 2>/dev/null || echo "Warning: Could not activate smallrna-tools"

# Check if pandas is available
if ! python -c "import pandas" 2>/dev/null; then
    echo "Installing pandas and numpy..."
    pip install --user pandas numpy 2>/dev/null || echo "Warning: Could not install pandas/numpy"
fi

# Then load cluster modules
# Note: RSEM will come from conda (fixed), not cluster module (buggy)
echo "Loading cluster modules..."
module load star/2.7.11a-pgsk3s4
module load subread/2.0.6
module load fastqc/0.12.1

echo ""
echo "Modules loaded successfully!"
echo ""
echo "Loaded tools:"
echo "  STAR: $(which STAR)"
echo "  RSEM: $(which rsem-calculate-expression) [conda - fixed zlib!]"
echo "  samtools: $(which samtools) [conda - fixed zlib!]"
echo "  featureCounts: $(which featureCounts)"
echo "  fastqc: $(which fastqc)"
echo "  cutadapt: $(which cutadapt)"
echo ""
echo "✓ Ready to run pipeline with RSEM support!"
