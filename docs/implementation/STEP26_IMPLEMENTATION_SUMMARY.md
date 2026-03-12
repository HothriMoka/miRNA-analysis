# Step 26 Implementation Summary

## Date: February 16, 2026

## What Was Implemented

Step 26 (Coverage Visualization) has been successfully implemented to visualize EMapper BigWig results using deepTools.

## New Files Created

### 1. Core Scripts

**`scripts/create_rna_type_beds.py`**
- Creates BED files for different RNA types from GTF annotation
- Extracts: miRNA, tRNA, rRNA, snoRNA, snRNA, protein_coding, lncRNA
- Already executed successfully - BED files are ready in `references/bed_files/`

**`06_visualize_coverage.sh`**
- Main SLURM script for coverage visualization
- Processes all samples automatically
- Generates 2 plots per sample:
  - Coverage density heatmap
  - Meta-gene profile plot
- Resources: 4 CPUs, 16GB RAM, ~4-8 hours for 35 samples

**`RUN_FULL_PIPELINE_WITH_VIZ.sh`**
- Master orchestration script
- Submits 3 jobs with dependencies:
  1. RSEM quantification
  2. EMapper coverage
  3. Coverage visualization (NEW)

### 2. Documentation

**`VISUALIZATION_GUIDE.md`**
- Complete guide to Step 26
- Usage instructions (batch and single sample)
- Troubleshooting section
- Plot interpretation guide

**Updated `PIPELINE_OVERVIEW.md`**
- Added Step 6 visualization to workflow
- Updated output structure to include `07_coverage_plots/`
- Updated resource requirements table
- Added deepTools to software dependencies

## Setup Completed

### BED Files Created ✅
```
references/bed_files/
├── mm39_miRNA.bed          (2201 genes, 78K)
├── mm39_tRNA.bed           (22 genes, 561 bytes)
├── mm39_rRNA.bed           (356 genes, 13K)
├── mm39_snoRNA.bed         (1507 genes, 53K)
├── mm39_snRNA.bed          (1381 genes, 49K)
├── mm39_protein_coding.bed (21760 genes, 736K)
└── mm39_lncRNA.bed         (32889 genes, 1.2M)
```

### Software Installed ✅
- **deepTools 3.5.6** installed in `smallrna-tools` conda environment
- Includes: `computeMatrix`, `plotHeatmap`, `plotProfile`
- Dependencies: matplotlib, numpy, sphinx (all installed)

## Pipeline Integration

### Option 1: Run Full Pipeline with Visualization (Recommended)
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline
bash RUN_FULL_PIPELINE_WITH_VIZ.sh
```

This will submit 3 jobs:
1. **RSEM** → quantification for all samples
2. **EMapper** → BigWig generation (waits for RSEM)
3. **Visualization** → coverage plots (waits for EMapper)

### Option 2: Run Visualization Only (After EMapper Completes)
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline
sbatch 06_visualize_coverage.sh
```

Use this if EMapper is already complete.

## Expected Outputs

For each sample, the following will be created in `07_coverage_plots/`:

```
SAMPLE_NAME_output/07_coverage_plots/
├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.png
├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.svg
├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.png
├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.svg
├── density_plot.log
└── metagene_plot.log
```

## Current Status

### EMapper Job
- **Job ID**: 900491
- **Status**: RUNNING (as of 17:52)
- **Expected completion**: ~1-2 hours more

### Next Steps

**When EMapper completes:**

1. **Option A - Submit visualization immediately:**
   ```bash
   sbatch 06_visualize_coverage.sh
   ```

2. **Option B - Run full pipeline from scratch:**
   ```bash
   bash RUN_FULL_PIPELINE_WITH_VIZ.sh
   ```
   (Use this for future runs on new samples)

### Monitoring Visualization

```bash
# Check job status
squeue -u $USER

# View live log
tail -f logs/coverage_viz_<JOB_ID>.log

# Check progress (count completed samples)
ls -d mouse_miRNA/*_output/07_coverage_plots/*.png 2>/dev/null | wc -l

# View plots when done
eog mouse_miRNA/*_output/07_coverage_plots/*_density_heatmap.png
```

## Resource Requirements

| Task | CPUs | Memory | Time (35 samples) |
|------|------|--------|-------------------|
| BED file creation | 1 | 2GB | ~2 min (DONE) |
| Visualization | 4 | 16GB | ~4-8 hours |

## Key Features

✅ **Automatic BED generation** - RNA type regions extracted from GTF  
✅ **deepTools integration** - Publication-quality plots  
✅ **Batch processing** - All samples visualized automatically  
✅ **Multiple output formats** - PNG (raster) and SVG (vector)  
✅ **Smart sampling** - Uses 500 genes per RNA type for faster processing  
✅ **Comprehensive logging** - Separate logs per plot type  

## Plot Interpretation

### Density Heatmap
- Shows coverage distribution across RNA types
- Rows = RNA types (miRNA, tRNA, etc.)
- Color intensity = read coverage
- **Look for**: Strong miRNA signal, low rRNA contamination

### Meta-Gene Profile
- Shows average coverage from TSS to TES
- Lines = different RNA types
- **Look for**: 5' or 3' bias, uniform coverage

## Troubleshooting

### No plots generated?
```bash
# Check BigWig files exist
ls mouse_miRNA/*/06_emapper/*.bw

# Check visualization logs
cat mouse_miRNA/SAMPLE_NAME_output/07_coverage_plots/*.log
```

### deepTools error?
```bash
# Verify installation
conda activate smallrna-tools
computeMatrix --version  # Should show: 3.5.6
```

## Documentation

- **VISUALIZATION_GUIDE.md** - Detailed guide
- **PIPELINE_OVERVIEW.md** - Updated with Step 6
- **LOG_FILES_GUIDE.md** - Log file locations

## Notes

1. **BED files are persistent** - Once created, they're reused for all samples
2. **Sampling strategy** - Uses 500 genes per RNA type to balance quality vs. speed
3. **File sizes** - Each sample generates ~1-5MB of visualization files
4. **Time estimate** - ~10-15 minutes per sample for both plots

## Questions?

Check the logs:
```bash
less logs/coverage_viz_*.log
less mouse_miRNA/SAMPLE_NAME_output/07_coverage_plots/density_plot.log
```

---

**Implementation completed successfully!** 🎉

The visualization pipeline is ready to run once EMapper completes.
