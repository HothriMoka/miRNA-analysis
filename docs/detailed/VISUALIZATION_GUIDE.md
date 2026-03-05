# Coverage Visualization Guide (Step 26)

## Overview

Step 26 generates publication-quality coverage density plots from the BigWig files produced by EMapper (Step 25). These visualizations show how sequencing reads are distributed across different RNA types (miRNA, tRNA, rRNA, etc.) and across meta-gene regions.

## What Gets Visualized?

### 1. Coverage Density Heatmap
- **File**: `*_bed_density_heatmap.png`
- **Shows**: Read coverage distribution across different RNA types
- **Uses**: Heatmap showing coverage intensity per RNA type
- **Purpose**: Compare coverage patterns between RNA biotypes

### 2. Meta-Gene Profile Plot
- **File**: `*_bed_stacked_profile_meta_gene.png`
- **Shows**: Average coverage profile across gene bodies
- **Uses**: Stacked line plot showing TSS → TES coverage
- **Purpose**: Identify 5' or 3' bias in sequencing coverage

## Generated Files

### Input Requirements
1. **BigWig files** from EMapper (Step 25)
   - `SAMPLE_NAME_final_unstranded.bw` (primary)
   - `SAMPLE_NAME_final_F1R2.bw` (optional)
   - `SAMPLE_NAME_final_F2R1.bw` (optional)

2. **BED files** for RNA types (auto-generated)
   - `mm39_miRNA.bed`
   - `mm39_tRNA.bed`
   - `mm39_rRNA.bed`
   - `mm39_snoRNA.bed`
   - `mm39_snRNA.bed`
   - `mm39_protein_coding.bed`
   - `mm39_lncRNA.bed`

### Output Files

For each sample `SAMPLE_NAME`:
```
SAMPLE_NAME_output/
└── 07_coverage_plots/
    ├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.png         # Density heatmap
    ├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.svg         # Vector format
    ├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.png  # Meta-gene plot
    ├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.svg  # Vector format
    ├── density_plot.log                                             # Density plot log
    └── metagene_plot.log                                            # Meta-gene log
```

## Usage

### Option 1: Run with Full Pipeline (Recommended)

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Run complete pipeline: RSEM → EMapper → Visualization
bash RUN_FULL_PIPELINE_WITH_VIZ.sh
```

This will submit three jobs with dependencies:
1. **Job 1**: RSEM quantification (04_rerun_rsem_all_samples.sh)
2. **Job 2**: EMapper coverage (05_run_emapper_all_samples.sh) - waits for Job 1
3. **Job 3**: Coverage visualization (06_visualize_coverage.sh) - waits for Job 2

### Option 2: Run Visualization Only (After EMapper)

```bash
# If EMapper is already complete, run visualization separately
sbatch 06_visualize_coverage.sh
```

### Option 3: Visualize Single Sample

```bash
# Navigate to pipeline directory
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Activate conda environment
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

# Set paths
SAMPLE_NAME="204913_S13"
BIGWIG="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/${SAMPLE_NAME}_output/06_emapper/${SAMPLE_NAME}_final_unstranded.bw"
OUTPUT_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/${SAMPLE_NAME}_output/07_coverage_plots"
BED_DIR="references/bed_files"

# Create output directory
mkdir -p ${OUTPUT_DIR}

# Generate BED files (if not already created)
if [ ! -d "${BED_DIR}" ]; then
    python scripts/create_rna_type_beds.py \
        --gtf references/annotations/gencode.vM38.annotation.gtf \
        --output_dir ${BED_DIR}
fi

# Run density plot
bash /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/bin/Step_26_density_plot_over_RNA_types.sh \
    --input_bw_file "${BIGWIG}" \
    --input_bed_files "[${BED_DIR}/mm39_miRNA.bed,${BED_DIR}/mm39_tRNA.bed,${BED_DIR}/mm39_rRNA.bed,${BED_DIR}/mm39_protein_coding.bed,${BED_DIR}/mm39_lncRNA.bed]" \
    --input_bed_labels "[miRNA,tRNA,rRNA,protein_coding,lncRNA]" \
    --output_dir "${OUTPUT_DIR}" \
    --random_tested_row_num_per_bed 500

# Run meta-gene plot
bash /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/bin/Step_26_density_plot_over_meta_gene.sh \
    --input_bw_file "${BIGWIG}" \
    --input_bed_files "[${BED_DIR}/mm39_miRNA.bed,${BED_DIR}/mm39_tRNA.bed,${BED_DIR}/mm39_rRNA.bed,${BED_DIR}/mm39_protein_coding.bed,${BED_DIR}/mm39_lncRNA.bed]" \
    --input_bed_labels "[miRNA,tRNA,rRNA,protein_coding,lncRNA]" \
    --output_dir "${OUTPUT_DIR}" \
    --random_tested_row_num_per_bed 500
```

## BED File Generation

BED files define genomic regions for each RNA type. They are automatically generated from the GTF annotation.

### Manual BED Generation

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

python scripts/create_rna_type_beds.py \
    --gtf references/annotations/gencode.vM38.annotation.gtf \
    --output_dir references/bed_files \
    --rna_types miRNA tRNA rRNA snoRNA snRNA protein_coding lncRNA
```

### Expected Output

```
==================================================
Creating BED files for RNA types
==================================================
GTF file: references/annotations/gencode.vM38.annotation.gtf
Output directory: references/bed_files
RNA types: miRNA, tRNA, rRNA, snoRNA, snRNA, protein_coding, lncRNA

Reading GTF: references/annotations/gencode.vM38.annotation.gtf
✓ Created references/bed_files/mm39_miRNA.bed (1231 genes)
✓ Created references/bed_files/mm39_tRNA.bed (457 genes)
✓ Created references/bed_files/mm39_rRNA.bed (685 genes)
✓ Created references/bed_files/mm39_snoRNA.bed (1435 genes)
✓ Created references/bed_files/mm39_snRNA.bed (1894 genes)
✓ Created references/bed_files/mm39_protein_coding.bed (21995 genes)
✓ Created references/bed_files/mm39_lncRNA.bed (11974 genes)

==================================================
Summary
==================================================
  miRNA               :   1231 genes
  tRNA                :    457 genes
  rRNA                :    685 genes
  snoRNA              :   1435 genes
  snRNA               :   1894 genes
  protein_coding      :  21995 genes
  lncRNA              :  11974 genes

✓ BED files created successfully!
```

## Understanding the Plots

### Density Heatmap

**Interpretation**:
- **Rows**: Different RNA types (miRNA, tRNA, rRNA, etc.)
- **Columns**: Position within gene (5' → 3')
- **Color intensity**: Read coverage (darker = more reads)

**What to look for**:
- **miRNA enrichment**: Should show strong signal if small RNA library worked
- **rRNA contamination**: High rRNA signal indicates poor rRNA depletion
- **Coverage patterns**: Uniform vs. biased (5' or 3')

### Meta-Gene Profile

**Interpretation**:
- **X-axis**: Position within gene (TSS → TES)
- **Y-axis**: Average coverage (normalized)
- **Lines**: Different RNA types (color-coded)

**What to look for**:
- **5' bias**: Reads concentrated at transcription start site
- **3' bias**: Reads concentrated at transcription end site
- **Uniform coverage**: Reads evenly distributed (ideal)

## Resource Requirements

| Samples | CPUs | Memory | Time | Partition |
|---------|------|--------|------|-----------|
| 1 | 4 | 16GB | ~10 min | cpu |
| 10 | 4 | 16GB | ~2 hours | cpu |
| 35 | 4 | 16GB | ~6 hours | cpu |

## Dependencies

### Software Requirements

**deepTools** (via conda):
- `computeMatrix`: Compute coverage matrix from BigWig + BED
- `plotHeatmap`: Generate density heatmap
- `plotProfile`: Generate meta-gene profile

**Python packages**:
- `matplotlib`: Plot generation
- `numpy`: Numerical operations

### Installation

```bash
# Install deepTools in conda environment
conda activate smallrna-tools
pip install deeptools

# Verify installation
computeMatrix --version
plotHeatmap --version
```

## Troubleshooting

### No Plots Generated

**Symptom**: `07_coverage_plots/` directory is empty

**Solutions**:
1. Check BigWig files exist:
   ```bash
   ls -lh mouse_miRNA/*/06_emapper/*.bw
   ```

2. Check BED files exist:
   ```bash
   ls -lh references/bed_files/*.bed
   ```

3. Check visualization logs:
   ```bash
   cat mouse_miRNA/SAMPLE_NAME_output/07_coverage_plots/density_plot.log
   cat mouse_miRNA/SAMPLE_NAME_output/07_coverage_plots/metagene_plot.log
   ```

### deepTools Not Found

**Symptom**: `computeMatrix: command not found`

**Solution**:
```bash
conda activate smallrna-tools
pip install deeptools
```

### Empty BED Files

**Symptom**: `Warning: BED file is empty, skipping`

**Solution**: Check GTF annotation has the expected RNA types
```bash
grep -c 'gene_type "miRNA"' references/annotations/gencode.vM38.annotation.gtf
```

Should return >1000 for miRNA. If not, check GTF format.

### Permission Denied

**Symptom**: `Permission denied` when running scripts

**Solution**: Make scripts executable
```bash
chmod +x 06_visualize_coverage.sh
chmod +x scripts/create_rna_type_beds.py
```

## Monitoring

### Check Job Status

```bash
# Check if visualization job is running
squeue -u $USER | grep coverage_viz

# View job details
sacct -j <JOB_ID> --format=JobID,JobName,State,Elapsed,MaxRSS,NodeList

# Follow log in real-time
tail -f logs/coverage_viz_<JOB_ID>.log
```

### Check Progress

```bash
# Count completed samples
ls -d mouse_miRNA/*_output/07_coverage_plots/*.png 2>/dev/null | wc -l

# Check which samples are done
for dir in mouse_miRNA/*_output; do
    sample=$(basename $dir _output)
    if [ -f "${dir}/07_coverage_plots/${sample}_final_unstranded_bed_density_heatmap.png" ]; then
        echo "✓ $sample"
    else
        echo "✗ $sample"
    fi
done
```

## Output File Sizes

**Expected file sizes** (per sample):
- **PNG plots**: ~500KB - 2MB each
- **SVG plots**: ~100KB - 500KB each (vector format, scalable)
- **Log files**: ~10-50KB each

**Total per sample**: ~1-5MB

## Next Steps

After visualization completes:

1. **View plots**: Open PNG files in image viewer
   ```bash
   # View all density heatmaps
   eog mouse_miRNA/*_output/07_coverage_plots/*_density_heatmap.png
   ```

2. **Quality assessment**: Check for:
   - Strong miRNA signal
   - Low rRNA contamination
   - Expected coverage patterns

3. **Publication**: Use SVG files for papers (vector graphics)

4. **Downstream analysis**: Use BigWig files for:
   - Genome browser visualization (IGV, UCSC)
   - Custom analysis scripts
   - Differential coverage analysis

## Related Documentation

- **Step 25 (EMapper)**: `05_run_emapper_all_samples.sh` - Generates BigWig files
- **Pipeline Overview**: `PIPELINE_OVERVIEW.md` - Complete workflow
- **Log Files Guide**: `LOG_FILES_GUIDE.md` - Finding and interpreting logs

## Contact

For issues with visualization:
1. Check logs in `07_coverage_plots/*.log`
2. Verify BigWig files in `06_emapper/*.bw`
3. Check SLURM job logs in `logs/coverage_viz_*.log`
