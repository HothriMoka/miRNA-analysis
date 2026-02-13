#!/bin/bash
#SBATCH --job-name=smRNA_batch
#SBATCH --output=logs/batch_%j.log
#SBATCH --error=logs/batch_%j.err
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --partition=cpu
#
# batch_process.sh - Process multiple samples in parallel or sequentially
#
# Resource requirements (for sequential mode):
#   - Memory: 48GB (for STAR alignment per sample)
#   - CPUs: 16 (for each sample, max for cpu partition)
#   - Time: depends on number of samples (~1 hour per sample)
#
# For PARALLEL mode, submit individual jobs instead:
#   See example below in usage section
#
# Usage:
#   Sequential (one SLURM job for all samples):
#     sbatch 03_batch_process.sh /path/to/fastqs --threads 16
#
#   Parallel (separate job per sample - RECOMMENDED):
#     for fq in /path/to/fastqs/*.fastq.gz; do
#       sample=$(basename $fq | sed 's/_R1_001.fastq.gz$//')
#       sbatch 02_smRNA_analysis.sh $sample $fq --threads 16
#     done
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# ============================================================================
# LOAD REQUIRED MODULES
# ============================================================================

# Load required modules (suppress errors if already loaded)
module load star/2.7.11a-pgsk3s4 rsem/1.3.3 subread/2.0.6 fastqc/0.12.1 samtools/1.17-xtpk2gu 2>/dev/null || true

# Activate conda environment for cutadapt if available
if command -v conda &> /dev/null; then
    source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
    conda activate smallrna-tools 2>/dev/null || true
fi

# Get script directory - use SLURM_SUBMIT_DIR when run via sbatch, otherwise use script location
if [ -n "${SLURM_SUBMIT_DIR}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
ANALYSIS_SCRIPT="${SCRIPT_DIR}/02_smRNA_analysis.sh"

# Change to script directory
cd "${SCRIPT_DIR}"

# Default settings
THREADS=16
PARALLEL=false
MAX_PARALLEL=3

# ============================================================================
# USAGE
# ============================================================================

usage() {
    cat << EOF
Usage: $0 <input_directory> [options]

Process multiple FASTQ files in a directory.

Required:
  input_directory    Directory containing FASTQ files (.fastq.gz or .fq.gz)

Options:
  --threads INT      Threads per sample (default: 20)
  --parallel         Run samples in parallel (default: sequential)
  --max-jobs INT     Max parallel jobs (default: 3)
  --pattern STR      File pattern (default: "*_R1_001.fastq.gz")
  --output-dir DIR   Output base directory (default: current directory)

Example:
  # Sequential processing
  $0 /path/to/fastqs --threads 16

  # Parallel processing (3 samples at a time)
  $0 /path/to/fastqs --parallel --max-jobs 3

EOF
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

INPUT_DIR="$1"
shift

PATTERN="*_R1_001.fastq.gz"
OUTPUT_BASE="."

while [[ $# -gt 0 ]]; do
    case $1 in
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --max-jobs)
            MAX_PARALLEL="$2"
            shift 2
            ;;
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_BASE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# ============================================================================
# VALIDATE INPUTS
# ============================================================================

if [[ ! -d "${INPUT_DIR}" ]]; then
    echo "ERROR: Input directory not found: ${INPUT_DIR}"
    exit 1
fi

if [[ ! -f "${ANALYSIS_SCRIPT}" ]]; then
    echo "ERROR: Analysis script not found: ${ANALYSIS_SCRIPT}"
    exit 1
fi

# Find FASTQ files
FASTQ_FILES=(${INPUT_DIR}/${PATTERN})

if [[ ${#FASTQ_FILES[@]} -eq 0 ]] || [[ ! -f "${FASTQ_FILES[0]}" ]]; then
    echo "ERROR: No FASTQ files found matching pattern: ${PATTERN}"
    echo "       in directory: ${INPUT_DIR}"
    exit 1
fi

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

echo "========================================"
echo "Batch Processing - Small RNA-seq"
echo "========================================"
echo ""
echo "Input directory: ${INPUT_DIR}"
echo "Pattern: ${PATTERN}"
echo "Samples found: ${#FASTQ_FILES[@]}"
echo "Threads per sample: ${THREADS}"
echo "Processing mode: $(${PARALLEL} && echo "Parallel (max ${MAX_PARALLEL} jobs)" || echo "Sequential")"
echo "Output directory: ${OUTPUT_BASE}"
echo ""
echo "Samples to process:"
for fq in "${FASTQ_FILES[@]}"; do
    SAMPLE=$(basename ${fq} | sed 's/_R1_001.fastq.gz$//' | sed 's/.fastq.gz$//' | sed 's/.fq.gz$//')
    echo "  - ${SAMPLE}"
done
echo ""

# Confirmation
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ============================================================================
# CREATE OUTPUT DIRECTORY
# ============================================================================

mkdir -p ${OUTPUT_BASE}
cd ${OUTPUT_BASE}

BATCH_LOG="batch_processing_$(date '+%Y%m%d_%H%M%S').log"

log_batch() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${BATCH_LOG}
}

log_batch "========================================"
log_batch "Batch processing started"
log_batch "Total samples: ${#FASTQ_FILES[@]}"
log_batch "========================================"
log_batch ""

# ============================================================================
# PROCESS SAMPLES
# ============================================================================

SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SAMPLES=()

if ${PARALLEL}; then
    # Parallel processing
    log_batch "Running in PARALLEL mode (max ${MAX_PARALLEL} concurrent jobs)"
    log_batch ""
    
    JOBCOUNT=0
    PIDS=()
    
    for fq in "${FASTQ_FILES[@]}"; do
        # Extract sample name
        SAMPLE=$(basename ${fq} | sed 's/_R1_001.fastq.gz$//' | sed 's/.fastq.gz$//' | sed 's/.fq.gz$//')
        
        log_batch "Starting sample: ${SAMPLE}"
        
        # Run in background
        (
            bash ${ANALYSIS_SCRIPT} ${SAMPLE} ${fq} --threads ${THREADS}
            if [[ $? -eq 0 ]]; then
                echo "SUCCESS:${SAMPLE}" >> ${OUTPUT_BASE}/.batch_results.tmp
            else
                echo "FAILED:${SAMPLE}" >> ${OUTPUT_BASE}/.batch_results.tmp
            fi
        ) &
        
        PID=$!
        PIDS+=($PID)
        JOBCOUNT=$((JOBCOUNT + 1))
        
        # Wait if we've reached max parallel jobs
        if [[ ${JOBCOUNT} -ge ${MAX_PARALLEL} ]]; then
            log_batch "Waiting for ${MAX_PARALLEL} jobs to complete..."
            wait ${PIDS[@]}
            PIDS=()
            JOBCOUNT=0
        fi
    done
    
    # Wait for remaining jobs
    if [[ ${#PIDS[@]} -gt 0 ]]; then
        log_batch "Waiting for remaining jobs to complete..."
        wait ${PIDS[@]}
    fi
    
    # Tally results
    if [[ -f "${OUTPUT_BASE}/.batch_results.tmp" ]]; then
        while IFS=: read -r status sample; do
            if [[ "${status}" == "SUCCESS" ]]; then
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                FAILED_COUNT=$((FAILED_COUNT + 1))
                FAILED_SAMPLES+=("${sample}")
            fi
        done < ${OUTPUT_BASE}/.batch_results.tmp
        rm -f ${OUTPUT_BASE}/.batch_results.tmp
    fi
    
else
    # Sequential processing
    log_batch "Running in SEQUENTIAL mode"
    log_batch ""
    
    for fq in "${FASTQ_FILES[@]}"; do
        # Extract sample name
        SAMPLE=$(basename ${fq} | sed 's/_R1_001.fastq.gz$//' | sed 's/.fastq.gz$//' | sed 's/.fq.gz$//')
        
        log_batch "Processing sample: ${SAMPLE} (${SUCCESS_COUNT}/${#FASTQ_FILES[@]} completed)"
        
        bash ${ANALYSIS_SCRIPT} ${SAMPLE} ${fq} --threads ${THREADS}
        
        if [[ $? -eq 0 ]]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            log_batch "✓ ${SAMPLE} completed successfully"
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_SAMPLES+=("${SAMPLE}")
            log_batch "✗ ${SAMPLE} FAILED"
        fi
        
        log_batch ""
    done
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================

log_batch "========================================"
log_batch "Batch Processing Complete"
log_batch "========================================"
log_batch ""
log_batch "Total samples: ${#FASTQ_FILES[@]}"
log_batch "Successful: ${SUCCESS_COUNT}"
log_batch "Failed: ${FAILED_COUNT}"
log_batch ""

if [[ ${FAILED_COUNT} -gt 0 ]]; then
    log_batch "Failed samples:"
    for sample in "${FAILED_SAMPLES[@]}"; do
        log_batch "  - ${sample}"
    done
    log_batch ""
fi

log_batch "Batch log: ${BATCH_LOG}"
log_batch ""

if [[ ${FAILED_COUNT} -eq 0 ]]; then
    log_batch "All samples processed successfully!"
    exit 0
else
    log_batch "Some samples failed. Check individual logs for details."
    exit 1
fi
