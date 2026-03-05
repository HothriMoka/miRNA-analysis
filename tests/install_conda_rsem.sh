#!/bin/bash
#SBATCH --job-name=install_rsem
#SBATCH --output=logs/install_rsem_%j.log
#SBATCH --error=logs/install_rsem_%j.err
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --partition=cpu

echo "=========================================="
echo "Installing RSEM in conda environment"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Date: $(date)"
echo ""

# Activate conda
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

echo "Conda environment: $CONDA_DEFAULT_ENV"
echo "Python: $(which python)"
echo ""

# Install RSEM using mamba (faster)
echo "Installing RSEM via mamba..."
mamba install -c bioconda rsem -y

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ RSEM installed successfully!"
    echo ""
    echo "Verifying installation:"
    which rsem-calculate-expression
    rsem-calculate-expression --version
    echo ""
    echo "Checking zlib linkage:"
    ldd $(which rsem-calculate-expression) | grep -E 'libz|zlib'
    echo ""
    echo "=========================================="
    echo "✓ Installation complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Test RSEM: bash test_conda_rsem.sh"
    echo "2. If working, update pipeline to use conda RSEM"
    echo "3. Test EMapper: bash 04_test_emapper.sh SAMPLE OUTPUT_DIR"
else
    echo ""
    echo "✗ Installation failed (exit code: $EXIT_CODE)"
    echo ""
    echo "Alternative: Request cluster admin to fix samtools/zlib-ng"
fi
