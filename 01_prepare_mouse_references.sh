#!/bin/bash
#SBATCH --job-name=prep_mouse_refs
#SBATCH --output=logs/prep_refs_%j.log
#SBATCH --error=logs/prep_refs_%j.err
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --partition=cpu
#
# prepare_mouse_references.sh
# Downloads and prepares mouse genome references for small RNA-seq analysis
# Uses GRCm39 (GENCODE M38) - Latest mouse genome release
#
# Resource requirements:
#   - Memory: 80GB (for STAR index building)
#   - CPUs: 16 (speeds up indexing, max for cpu partition)
#   - Time: ~1-2 hours (download + indexing)
#
# Usage:
#   sbatch 01_prepare_mouse_references.sh [threads]
#   OR
#   bash 01_prepare_mouse_references.sh [threads]
#

set -euo pipefail

# ============================================================================
# LOAD REQUIRED MODULES
# ============================================================================

echo "Loading required modules..."
module load star/2.7.11a-pgsk3s4 rsem/1.3.3 subread/2.0.6 samtools/1.17-xtpk2gu || {
    echo "WARNING: Could not load modules. Assuming tools are in PATH."
}

# Activate conda environment if available
if command -v conda &> /dev/null; then
    source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
    conda activate smallrna-tools 2>/dev/null || echo "Note: smallrna-tools conda env not activated"
fi

echo "✓ Environment loaded"
echo ""

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get script directory - use SLURM_SUBMIT_DIR when run via sbatch, otherwise use script location
if [ -n "${SLURM_SUBMIT_DIR}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
REF_DIR="${SCRIPT_DIR}/references"

# Change to script directory and verify
cd "${SCRIPT_DIR}" || { echo "ERROR: Cannot cd to ${SCRIPT_DIR}"; exit 1; }
echo "Working directory: $(pwd)"

# Use SLURM_CPUS_PER_TASK if available, otherwise use argument or default to 16
THREADS="${SLURM_CPUS_PER_TASK:-${1:-16}}"

# GENCODE Mouse M38 (GRCm39)
GENCODE_BASE="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M38"
GENOME_FA="GRCm39.primary_assembly.genome.fa.gz"
ANNOTATION_GTF="gencode.vM38.annotation.gtf.gz"

echo "========================================"
echo "Mouse Reference Preparation"
echo "GENCODE M38 (GRCm39)"
echo "========================================"
echo ""
echo "Script directory: ${SCRIPT_DIR}"
echo "Reference directory: ${REF_DIR}"
echo "Threads: ${THREADS}"
echo ""

# ============================================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================================

echo "Creating directory structure..."
mkdir -p "${REF_DIR}/genome" || { echo "ERROR: Cannot create ${REF_DIR}/genome"; exit 1; }
mkdir -p "${REF_DIR}/annotations" || { echo "ERROR: Cannot create ${REF_DIR}/annotations"; exit 1; }
mkdir -p "${REF_DIR}/indices/STAR" || { echo "ERROR: Cannot create ${REF_DIR}/indices/STAR"; exit 1; }
mkdir -p "${REF_DIR}/indices/RSEM" || { echo "ERROR: Cannot create ${REF_DIR}/indices/RSEM"; exit 1; }
mkdir -p "${REF_DIR}/indices/BWA" || { echo "ERROR: Cannot create ${REF_DIR}/indices/BWA"; exit 1; }
echo "✓ Directory structure created"

# ============================================================================
# DOWNLOAD REFERENCE FILES
# ============================================================================

echo ""
echo "=== Step 1: Downloading Reference Files ==="

# Download genome
if [[ ! -f "${REF_DIR}/genome/${GENOME_FA}" ]]; then
    echo "Downloading mouse genome (GRCm39)..."
    wget -q --show-progress -O "${REF_DIR}/genome/${GENOME_FA}" \
        "${GENCODE_BASE}/${GENOME_FA}"
    echo "Genome download complete!"
else
    echo "Genome already downloaded: ${REF_DIR}/genome/${GENOME_FA}"
fi

# Decompress genome
if [[ ! -f "${REF_DIR}/genome/GRCm39.genome.fa" ]]; then
    echo "Decompressing genome..."
    gunzip -c "${REF_DIR}/genome/${GENOME_FA}" > "${REF_DIR}/genome/GRCm39.genome.fa"
    echo "Genome decompressed!"
else
    echo "Genome already decompressed: ${REF_DIR}/genome/GRCm39.genome.fa"
fi

# Download annotation
if [[ ! -f "${REF_DIR}/annotations/${ANNOTATION_GTF}" ]]; then
    echo "Downloading GENCODE M38 annotations..."
    wget -q --show-progress -O "${REF_DIR}/annotations/${ANNOTATION_GTF}" \
        "${GENCODE_BASE}/${ANNOTATION_GTF}"
    echo "Annotation download complete!"
else
    echo "Annotation already downloaded: ${REF_DIR}/annotations/${ANNOTATION_GTF}"
fi

# Decompress annotation
if [[ ! -f "${REF_DIR}/annotations/gencode.vM38.annotation.gtf" ]]; then
    echo "Decompressing annotation..."
    gunzip -c "${REF_DIR}/annotations/${ANNOTATION_GTF}" > "${REF_DIR}/annotations/gencode.vM38.annotation.gtf"
    echo "Annotation decompressed!"
else
    echo "Annotation already decompressed: ${REF_DIR}/annotations/gencode.vM38.annotation.gtf"
fi

# ============================================================================
# CREATE GENE METADATA TABLE
# ============================================================================

echo ""
echo "=== Step 2: Creating Gene Metadata Table ==="

if [[ ! -f "${REF_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv" ]]; then
    python ${SCRIPT_DIR}/scripts/create_gene_metadata.py \
        --gtf ${REF_DIR}/annotations/gencode.vM38.annotation.gtf \
        --output ${REF_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv
else
    echo "Gene metadata already exists: ${REF_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv"
fi

# ============================================================================
# BUILD STAR INDEX
# ============================================================================

echo ""
echo "=== Step 3: Building STAR Index ==="
echo "This may take 30-60 minutes..."

if [[ ! -f "${REF_DIR}/indices/STAR/SAindex" ]]; then
    STAR --runMode genomeGenerate \
        --genomeDir ${REF_DIR}/indices/STAR \
        --genomeFastaFiles ${REF_DIR}/genome/GRCm39.genome.fa \
        --sjdbGTFfile ${REF_DIR}/annotations/gencode.vM38.annotation.gtf \
        --sjdbOverhang 69 \
        --runThreadN ${THREADS} \
        --genomeSAindexNbases 13 \
        --limitGenomeGenerateRAM 110000000000
    
    echo "STAR index built successfully!"
else
    echo "STAR index already exists: ${REF_DIR}/indices/STAR/"
fi

# ============================================================================
# BUILD RSEM INDEX
# ============================================================================

echo ""
echo "=== Step 4: Building RSEM Index ==="
echo "This may take 20-40 minutes..."

if [[ ! -f "${REF_DIR}/indices/RSEM/RSEM_REF_MM39.grp" ]]; then
    rsem-prepare-reference \
        --gtf ${REF_DIR}/annotations/gencode.vM38.annotation.gtf \
        --bowtie2 \
        --num-threads ${THREADS} \
        ${REF_DIR}/genome/GRCm39.genome.fa \
        ${REF_DIR}/indices/RSEM/RSEM_REF_MM39
    
    echo "RSEM index built successfully!"
else
    echo "RSEM index already exists: ${REF_DIR}/indices/RSEM/RSEM_REF_MM39"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================"
echo "Reference Preparation Complete!"
echo "========================================"
echo ""
echo "Reference files location: ${REF_DIR}"
echo ""
echo "Contents:"
echo "  - Genome: ${REF_DIR}/genome/GRCm39.genome.fa"
echo "  - GTF: ${REF_DIR}/annotations/gencode.vM38.annotation.gtf"
echo "  - Metadata: ${REF_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv"
echo "  - STAR Index: ${REF_DIR}/indices/STAR/"
echo "  - RSEM Index: ${REF_DIR}/indices/RSEM/RSEM_REF_MM39"
echo ""
echo "Ready to run analysis pipeline!"
echo ""

# Verify critical files exist
echo "Verifying files..."
ERRORS=0

if [[ ! -f "${REF_DIR}/genome/GRCm39.genome.fa" ]]; then
    echo "ERROR: Genome FASTA not found!"
    ERRORS=$((ERRORS + 1))
fi

if [[ ! -f "${REF_DIR}/annotations/gencode.vM38.annotation.gtf" ]]; then
    echo "ERROR: GTF not found!"
    ERRORS=$((ERRORS + 1))
fi

if [[ ! -f "${REF_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv" ]]; then
    echo "ERROR: Gene metadata not found!"
    ERRORS=$((ERRORS + 1))
fi

if [[ ! -f "${REF_DIR}/indices/STAR/SAindex" ]]; then
    echo "ERROR: STAR index not complete!"
    ERRORS=$((ERRORS + 1))
fi

if [[ ! -f "${REF_DIR}/indices/RSEM/RSEM_REF_MM39.grp" ]]; then
    echo "ERROR: RSEM index not complete!"
    ERRORS=$((ERRORS + 1))
fi

if [[ ${ERRORS} -eq 0 ]]; then
    echo "✓ All reference files verified successfully!"
    exit 0
else
    echo "✗ ${ERRORS} error(s) found. Please check the logs above."
    exit 1
fi
