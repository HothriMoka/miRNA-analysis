#!/bin/bash
#SBATCH --job-name=rsem_rerun_all
#SBATCH --output=logs/rsem_rerun_all_%j.log
#SBATCH --error=logs/rsem_rerun_all_%j.err
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --partition=hmem

################################################################################
# Re-run RSEM for all samples that are missing transcriptome BAM and RSEM results
# Uses conda's fixed RSEM (with zlib-ng 2.2.5) to avoid bgzf bug
################################################################################

set -euo pipefail

# Get script directory
if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "${SCRIPT_DIR}"

# Paths
REFS_DIR="${SCRIPT_DIR}/references"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
OUTPUT_BASE="${OUTPUT_BASE:-}"

if [ -z "${OUTPUT_BASE}" ]; then
    echo "ERROR: OUTPUT_BASE is not set."
    echo "       Please set OUTPUT_BASE before running this script,"
    echo "       or run it via Run_SmallRNA_Pipeline.sh which configures it for you."
    exit 1
fi
RSEM_INDEX="${REFS_DIR}/indices/RSEM/RSEM_REF_MM39"
GENE_META="${REFS_DIR}/annotations/mm39_geneID_Symbol_RNAtype.tsv"

# Use SLURM allocation if available
THREADS="${SLURM_CPUS_PER_TASK:-8}"

echo "========================================"
echo "Re-running RSEM for All Samples"
echo "========================================"
echo "Output directory: ${OUTPUT_BASE}"
echo "RSEM index: ${RSEM_INDEX}"
echo "Threads: ${THREADS} (cpu partition, 8 CPUs, 48GB - fast scheduling)"
echo ""

# Load conda environment FIRST (contains fixed RSEM with zlib-ng 2.2.5)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading conda environment..."
if command -v conda &> /dev/null; then
    source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
    conda activate smallrna-tools 2>/dev/null || true
fi

echo "✓ Conda environment: ${CONDA_DEFAULT_ENV:-none}"
echo "✓ RSEM location: $(which rsem-calculate-expression 2>/dev/null || echo 'not found')"
echo ""

# Verify conda RSEM is being used
RSEM_PATH=$(which rsem-calculate-expression 2>/dev/null || echo "")
if [[ ! "$RSEM_PATH" =~ "conda" ]] && [[ ! "$RSEM_PATH" =~ "miniconda" ]]; then
    echo "WARNING: Not using conda's RSEM. Path: $RSEM_PATH"
    echo "This may cause bgzf errors!"
fi

# Check RSEM index exists
if [ ! -f "${RSEM_INDEX}.grp" ]; then
    echo "ERROR: RSEM index not found: ${RSEM_INDEX}.grp"
    exit 1
fi

# Counters
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
FAILED_SAMPLES=()

# Process each sample
cd "${OUTPUT_BASE}"

for dir in *_output; do
    SAMPLE_NAME=$(basename "$dir" _output)
    SAMPLE_DIR="${OUTPUT_BASE}/${dir}"
    
    # Check if RSEM already complete
    TRANSCRIPTOME_BAM="${SAMPLE_DIR}/02_aligned/${SAMPLE_NAME}_Aligned.toTranscriptome.out.bam"
    RSEM_RESULTS="${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM.genes.results"
    
    if [ -f "$TRANSCRIPTOME_BAM" ] && [ -f "$RSEM_RESULTS" ] && [ -s "$RSEM_RESULTS" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ ${SAMPLE_NAME} - RSEM already complete"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))

        # Regenerate plots if missing (prefer featureCounts TPM matrices)
        FC_TPM="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_featureCounts_TPM.tsv"
        FC_FULL_TPM="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_featureCounts_all_genes_TPM.tsv"
        PLOT_INPUT="${FC_FULL_TPM}"
        if [ ! -f "${PLOT_INPUT}" ]; then
            PLOT_INPUT="${FC_TPM}"
        fi

        if [ -f "${PLOT_INPUT}" ]; then
            RNA_DIST_OUTPUT="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_RNA_distribution_2subplots"
            TOP_GENES_PDF="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.pdf"
            BARPLOT_OUTPUT="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_GeneType_Barplot.pdf"

            if [ ! -f "${RNA_DIST_OUTPUT}.pdf" ]; then
                echo "    Regenerating RNA distribution plot (featureCounts-based)..."
                python ${SCRIPTS_DIR}/plot_RNA_distribution_2subplots.py \
                    --input ${PLOT_INPUT} \
                    --output ${RNA_DIST_OUTPUT} \
                    --sample_name ${SAMPLE_NAME} \
                    > ${SAMPLE_DIR}/logs/rna_distribution.log 2>&1 && echo "      ✓ RNA distribution plot generated" || echo "      ⚠ RNA distribution plot failed"
            fi
            if [ ! -f "${TOP_GENES_PDF}" ]; then
                echo "    Regenerating top expressed genes plot (featureCounts-based)..."
                python ${SCRIPTS_DIR}/plot_top_expressed_genes.py \
                    --input ${PLOT_INPUT} \
                    --output_pdf ${TOP_GENES_PDF} \
                    --output_png ${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.png \
                    --genes_per_type 3 --total_genes 50 --sample_name ${SAMPLE_NAME} \
                    > ${SAMPLE_DIR}/logs/top_genes.log 2>&1 && echo "      ✓ Top genes plot generated" || echo "      ⚠ Top genes plot failed"
            fi
            if [ ! -f "${BARPLOT_OUTPUT}" ]; then
                echo "    Regenerating gene type barplot (featureCounts-based)..."
                python ${SCRIPTS_DIR}/plot_genetype_barplot.py \
                    --input ${PLOT_INPUT} --output ${BARPLOT_OUTPUT} \
                    --top 15 --title \"Gene Type Distribution - ${SAMPLE_NAME}\" --min_tpm 0 \
                    > ${SAMPLE_DIR}/logs/barplot.log 2>&1 && echo "      ✓ Gene type barplot generated" || echo "      ⚠ Gene type barplot failed"
            fi
        fi
        echo ""
        continue
    fi
    
    echo ""
    echo "========================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: ${SAMPLE_NAME}"
    echo "========================================"
    
    # Check if transcriptome BAM exists (from STAR)
    if [ ! -f "$TRANSCRIPTOME_BAM" ]; then
        echo "✗ ERROR: Transcriptome BAM not found: $TRANSCRIPTOME_BAM"
        echo "  STAR may not have generated it. Need to re-run STAR first."
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SAMPLES+=("${SAMPLE_NAME} - missing transcriptome BAM")
        continue
    fi
    
    echo "  Found transcriptome BAM: $(du -h ${TRANSCRIPTOME_BAM} | cut -f1)"
    
    # Clean up previous failed RSEM run
    echo "  Cleaning up previous RSEM run..."
    rm -f "${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM.genes.results"
    rm -f "${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM.isoforms.results"
    rm -rf "${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM.temp"
    rm -rf "${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM.stat"
    
    # Run RSEM
    echo "  Running RSEM with conda's fixed version..."
    
    RSEM_PREFIX="${SAMPLE_DIR}/03_counts/${SAMPLE_NAME}_RSEM"
    RSEM_LOG="${SAMPLE_DIR}/logs/rsem_rerun.log"
    
    rsem-calculate-expression \
        --bam \
        --no-bam-output \
        -p ${THREADS} \
        --seed 12345 \
        ${TRANSCRIPTOME_BAM} \
        ${RSEM_INDEX} \
        ${RSEM_PREFIX} \
        > ${RSEM_LOG} 2>&1
    
    RSEM_EXIT=$?
    
    if [ ${RSEM_EXIT} -eq 0 ] && [ -f "$RSEM_RESULTS" ] && [ -s "$RSEM_RESULTS" ]; then
        GENES_DETECTED=$(awk '$6 > 0' ${RSEM_RESULTS} | tail -n +2 | wc -l)
        echo "  ✓ RSEM completed successfully!"
        echo "    Genes detected (TPM>0): ${GENES_DETECTED}"
        
        # Generate TPM expression matrix
        echo "  Generating RSEM TPM expression matrix..."
        RSEM_TPM="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_RSEM_TPM.tsv"
        
        python ${SCRIPTS_DIR}/Step_17_RSEM2expr_matrix.py \
            --RSEM_out ${RSEM_RESULTS} \
            --GeneID_meta_table ${GENE_META} \
            --output ${RSEM_TPM} \
            > ${SAMPLE_DIR}/logs/rsem_to_tpm_rerun.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "    ✓ RSEM TPM matrix generated!"
            
            # Extract miRNAs
            MIRNA_RSEM="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_miRNAs_only_RSEM.tsv"
            awk -F'\t' 'NR==1 || $3~/miRNA/' ${RSEM_TPM} > ${MIRNA_RSEM}
            MIRNA_COUNT=$(tail -n +2 ${MIRNA_RSEM} | wc -l)
            MIRNA_DETECTED=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' ${RSEM_TPM} | wc -l)
            echo "    ✓ miRNAs annotated: ${MIRNA_COUNT}, detected: ${MIRNA_DETECTED}"
            
            # Generate RNA distribution plot (2 subplots)
            RNA_DIST_OUTPUT="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_RNA_distribution_2subplots"
            if [ ! -f "${RNA_DIST_OUTPUT}.pdf" ]; then
                echo "    Generating RNA distribution plot..."
                python ${SCRIPTS_DIR}/plot_RNA_distribution_2subplots.py \
                    --input ${RSEM_TPM} \
                    --output ${RNA_DIST_OUTPUT} \
                    --sample_name ${SAMPLE_NAME} \
                    > ${SAMPLE_DIR}/logs/rna_distribution.log 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "      ✓ RNA distribution plot generated"
                else
                    echo "      ⚠ RNA distribution plot failed (non-critical)"
                fi
            fi
            
            # Generate top expressed genes plot
            TOP_GENES_PDF="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.pdf"
            TOP_GENES_PNG="${SAMPLE_DIR}/04_expression/${SAMPLE_NAME}_top_expressed_genes.png"
            if [ ! -f "${TOP_GENES_PDF}" ]; then
                echo "    Generating top expressed genes plot..."
                python ${SCRIPTS_DIR}/plot_top_expressed_genes.py \
                    --input ${RSEM_TPM} \
                    --output_pdf ${TOP_GENES_PDF} \
                    --output_png ${TOP_GENES_PNG} \
                    --genes_per_type 3 \
                    --total_genes 50 \
                    --sample_name ${SAMPLE_NAME} \
                    > ${SAMPLE_DIR}/logs/top_genes.log 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "      ✓ Top genes plot generated"
                else
                    echo "      ⚠ Top genes plot failed (non-critical)"
                fi
            fi
            
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "    ✗ WARNING: TPM conversion failed"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_SAMPLES+=("${SAMPLE_NAME} - TPM conversion failed")
        fi
    else
        echo "  ✗ ERROR: RSEM failed with exit code ${RSEM_EXIT}"
        echo "    Check log: ${RSEM_LOG}"
        tail -20 ${RSEM_LOG}
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SAMPLES+=("${SAMPLE_NAME} - RSEM failed")
    fi
    
    echo ""
done

# Final summary
echo "========================================"
echo "RSEM RE-RUN COMPLETE"
echo "========================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
echo ""
echo "Total samples:  $(ls -d ${OUTPUT_BASE}/*_output | wc -l)"
echo "Already done:   ${SKIPPED_COUNT}"
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

echo "Output location: ${OUTPUT_BASE}/*/03_counts/*_RSEM.genes.results"
echo "TPM matrices:    ${OUTPUT_BASE}/*/04_expression/*_RSEM_TPM.tsv"
echo "miRNA results:   ${OUTPUT_BASE}/*/04_expression/*_miRNAs_only_RSEM.tsv"
echo ""

# Generate miRNA detection summary plot
if [ ${SUCCESS_COUNT} -gt 0 ] || [ ${SKIPPED_COUNT} -gt 0 ]; then
    echo ""
    echo "========================================"
    echo "Generating miRNA Detection Summary"
    echo "========================================"
    
    SUMMARY_OUTPUT="${OUTPUT_BASE}/miRNA_Detection_Summary.pdf"
    
    python ${SCRIPTS_DIR}/plot_mirna_detection_summary.py \
        --input_dir "${OUTPUT_BASE}" \
        --output "${SUMMARY_OUTPUT}" \
        --min_tpm 0 \
        > ${OUTPUT_BASE}/logs/mirna_summary.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ miRNA detection summary generated!"
        echo "  PDF:  ${SUMMARY_OUTPUT}"
        echo "  PNG:  ${SUMMARY_OUTPUT/.pdf/.png}"
        echo "  CSV:  ${SUMMARY_OUTPUT/.pdf/_data.csv}"
    else
        echo "WARNING: miRNA detection summary failed (check logs/mirna_summary.log)"
    fi
fi

echo ""

if [ ${FAILED_COUNT} -gt 0 ]; then
    echo "✗ Some samples had RSEM failures or TPM conversion issues. Check logs above."
else
    echo "✓ All samples processed successfully!"
fi

echo ""
echo "RSEM re-run step completed (non-fatal failures allowed)."
echo "Next step in full pipeline: EMapper and coverage visualization will still run."
exit 0
