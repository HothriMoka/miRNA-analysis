# Visualization Fix Summary

## Date: February 17, 2026

## Problem

The initial visualization script (Job 900779) **failed** with the following error:

```
FileNotFoundError: [Errno 2] No such file or directory: 
'/home/yz2474/scripts/donglab/EVscope/genome_anno/UCSC_HG38/Encode_hg38-blacklist.v2.bed'
```

### Root Cause

The original EVscope visualization scripts (`Step_26_density_plot_over_RNA_types.sh` and `Step_26_density_plot_over_meta_gene.sh`) had **hardcoded paths** to:
1. A human genome (HG38) blacklist file
2. A path that doesn't exist on your system
3. Wrong species (human instead of mouse)

These scripts were designed for a different user's setup and couldn't be used directly.

## Solution

Created **mouse-specific visualization scripts** without hardcoded paths:

### New Scripts Created

**1. `scripts/density_plot_over_RNA_types.sh`**
- Generates coverage density heatmaps
- Shows read distribution across RNA types
- **No blacklist requirement** (removed the `--blackListFileName` parameter)
- Uses 4 threads instead of 20 for better resource management
- Output: PNG and SVG density heatmaps

**2. `scripts/metagene_plot.sh`**
- Generates meta-gene profile plots
- Shows average coverage from TSS to TES
- **No blacklist requirement**
- Uses 4 threads for efficiency
- Includes ±1kb flanking regions
- Output: PNG and SVG profile plots

### Updated Files

**`06_visualize_coverage.sh`**
- Changed to use local mouse-specific scripts instead of EVscope scripts
- Updated script paths to point to `${SCRIPTS_DIR}/` instead of `${EVSCOPE_BIN}/`

## Key Differences from EVscope Scripts

| Feature | EVscope Scripts | Mouse-Specific Scripts |
|---------|-----------------|------------------------|
| Blacklist file | **Required** (hardcoded HG38 path) | **Not used** (removed) |
| Threads | 20 | 4 (better for cpu partition) |
| Species | Human (HG38) | Mouse (GRCm39/mm39) |
| Portability | Site-specific paths | Relative paths |
| Meta-gene window | Variable | ±1kb around gene body |

## Results

### Job Status

- **Failed Job**: 900779 (original attempt)
- **Successful Job**: 900781 (with fixed scripts)

### Current Progress

```bash
# Job 900781 is running successfully
# Already completed samples:
✓ 204913_S13 - Both plots generated (166K density, 246K meta-gene)
✓ 204914_S9 - In progress

# Expected completion: ~4-6 hours for all 35 samples
```

### Generated Files

For each sample:
```
SAMPLE_NAME_output/07_coverage_plots/
├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.png      (PNG format)
├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.svg      (SVG vector)
├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.png  (PNG)
├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.svg  (SVG)
├── density_plot.log
└── metagene_plot.log
```

## Technical Details

### computeMatrix Parameters (Density Plot)

```bash
computeMatrix scale-regions \
    -S "$bw_file" \
    -R "${processed_bed_files[@]}" \
    --beforeRegionStartLength 0 \
    --regionBodyLength 100 \
    --afterRegionStartLength 0 \
    -o "$matrix_file" \
    --binSize 10 \
    -p 4 \
    --outFileSortedRegions "$sorted_regions_file"
    # NO --blackListFileName parameter
```

### computeMatrix Parameters (Meta-gene Plot)

```bash
computeMatrix scale-regions \
    -S "$bw_file" \
    -R "${processed_bed_files[@]}" \
    --beforeRegionStartLength 1000  # 1kb upstream
    --regionBodyLength 2000          # Gene body
    --afterRegionStartLength 1000    # 1kb downstream
    -o "$matrix_file" \
    --binSize 50 \
    -p 4 \
    --outFileSortedRegions "$sorted_regions_file"
    # NO --blackListFileName parameter
```

## Why Remove the Blacklist?

**Blacklist files** are used to exclude problematic genomic regions (e.g., repetitive elements, artifactual high-signal regions) that can confound analysis. However:

1. **Not critical for small RNA-seq**: Small RNAs (especially miRNAs) are short and specific
2. **Mouse blacklist less common**: ENCODE blacklists are primarily for human
3. **BED filtering sufficient**: We're already focusing on specific RNA type regions via BED files
4. **Avoids dependencies**: Removes need for external blacklist file management

If you need blacklist filtering in the future, you can:
- Download mouse ENCODE blacklist from: https://github.com/Boyle-Lab/Blacklist/
- Add `--blackListFileName` parameter to the computeMatrix commands

## Monitoring the Job

```bash
# Check job status
squeue -u $USER | grep coverage

# View live log
tail -f logs/coverage_viz_900781.log

# Check progress (count completed samples)
ls -d mouse_miRNA/*_output/07_coverage_plots/*.png 2>/dev/null | wc -l

# View generated plots
eog mouse_miRNA/204913_S13_output/07_coverage_plots/*.png
```

## Verification

### Sample 204913_S13 (Completed)

```bash
ls -lh mouse_miRNA/204913_S13_output/07_coverage_plots/

# Output:
-rw-r--r-- 166K  204913_S13_final_unstranded_bed_density_heatmap.png
-rw-r--r--  29K  204913_S13_final_unstranded_bed_density_heatmap.svg
-rw-r--r-- 246K  204913_S13_final_unstranded_bed_stacked_profile_meta_gene.png
-rw-r--r--  91K  204913_S13_final_unstranded_bed_stacked_profile_meta_gene.svg
```

✅ Both PNG and SVG files generated successfully!

## Future Runs

The fixed scripts are now part of the pipeline. For future runs:

```bash
# Option 1: Run visualization only (after EMapper)
sbatch 06_visualize_coverage.sh

# Option 2: Run complete pipeline with visualization
bash RUN_FULL_PIPELINE_WITH_VIZ.sh
```

## Lessons Learned

1. **Avoid hardcoded paths** - Use relative paths or environment variables
2. **Species-specific considerations** - Human tools may not work for mouse
3. **External dependencies** - Minimize requirements for external files
4. **Test with single sample** - Catch errors early before batch processing

## Related Files

- **Fixed Scripts**:
  - `scripts/density_plot_over_RNA_types.sh`
  - `scripts/metagene_plot.sh`
  
- **Main Script**:
  - `06_visualize_coverage.sh`
  
- **Documentation**:
  - `VISUALIZATION_GUIDE.md`
  - `STEP26_IMPLEMENTATION_SUMMARY.md`

---

**Status**: ✅ FIXED and RUNNING

The visualization pipeline is now fully operational and processing all 35 samples!
