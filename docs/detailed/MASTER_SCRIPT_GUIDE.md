# Master Pipeline Script Guide

## Overview

The **`Run_SmallRNA_Pipeline.sh`** master script provides a single, unified interface to run the complete mouse small RNA-seq pipeline from reference building through visualization.

## Key Features

✅ **Single entry point** for the entire pipeline  
✅ **Easy configuration** - all paths and settings at the top  
✅ **Automatic job dependencies** - no manual coordination needed  
✅ **Flexible execution** - run full pipeline or skip steps  
✅ **Clear documentation** - comprehensive help and monitoring info  
✅ **Adapter customization** - easy to change for different kits  
✅ **Resource management** - configurable CPU/memory for each step  

## Quick Start

### 1. First Time Setup (Build References)

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Edit the configuration section
nano Run_SmallRNA_Pipeline.sh

# Build references (one-time, ~2-4 hours)
bash Run_SmallRNA_Pipeline.sh --build-references
```

### 2. Process New Samples

```bash
# Edit paths if needed
nano Run_SmallRNA_Pipeline.sh

# Run complete pipeline (Steps 02-06)
bash Run_SmallRNA_Pipeline.sh
```

### 3. Quick Processing (Skip Visualization)

```bash
# Run without coverage plots (faster)
bash Run_SmallRNA_Pipeline.sh --skip-viz
```

## Configuration

### Required Edits (Before First Run)

Open `Run_SmallRNA_Pipeline.sh` and edit the **CONFIGURATION SECTION** at the top:

```bash
################################################################################
# CONFIGURATION SECTION - EDIT THESE PATHS FOR YOUR ANALYSIS
################################################################################

# === INPUT FILES ===
# Directory containing your FASTQ files
INPUT_FASTQ_DIR="/path/to/your/fastq/files"

# === OUTPUT LOCATION ===
# Main output directory
OUTPUT_BASE_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA"

# === REFERENCE GENOME ===
# Reference directory (leave as default for mouse)
REFERENCE_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/references"

# === ADAPTER SEQUENCE ===
# Change based on your library prep kit
ADAPTER_SEQUENCE="AAAAAAAAAA"  # Takara SMARTer (default)
```

### Adapter Sequences for Common Kits

**Takara SMARTer smRNA-Seq** (default):
```bash
ADAPTER_SEQUENCE="AAAAAAAAAA"
```

**Illumina TruSeq Small RNA**:
```bash
ADAPTER_SEQUENCE="TGGAATTCTCGGGTGCCAAGG"
```

**NEBNext Small RNA**:
```bash
ADAPTER_SEQUENCE="AGATCGGAAGAGCACACGTCT"
```

**QIAseq miRNA**:
```bash
ADAPTER_SEQUENCE="AACTGTAGGCACCATCAAT"
```

### Resource Allocation (Optional)

Adjust CPU/memory based on your cluster limits:

```bash
# === RESOURCE ALLOCATION ===
REF_BUILD_CPUS=16
REF_BUILD_MEM="120G"

SINGLE_SAMPLE_CPUS=8
SINGLE_SAMPLE_MEM="48G"

RSEM_BATCH_CPUS=8
RSEM_BATCH_MEM="48G"

# And so on...
```

### SLURM Partition (Optional)

```bash
PARTITION="cpu"  # Options: cpu, hmem, nice
```

## Usage Examples

### Example 1: Complete New Analysis

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Edit configuration
nano Run_SmallRNA_Pipeline.sh
# Set INPUT_FASTQ_DIR="/data/experiment1/fastq"
# Set OUTPUT_BASE_DIR="/data/experiment1/results"
# Set ADAPTER_SEQUENCE="AAAAAAAAAA"  # Takara kit

# First run: Build references
bash Run_SmallRNA_Pipeline.sh --build-references

# After references complete: Process samples
bash Run_SmallRNA_Pipeline.sh
```

### Example 2: Process Additional Samples (References Already Built)

```bash
# Edit INPUT_FASTQ_DIR to point to new samples
nano Run_SmallRNA_Pipeline.sh

# Run pipeline (skips reference building)
bash Run_SmallRNA_Pipeline.sh
```

### Example 3: Quick Analysis Without Visualization

```bash
# Faster completion, skip coverage plots
bash Run_SmallRNA_Pipeline.sh --skip-viz
```

### Example 4: Different Library Prep Kit

```bash
# Edit adapter sequence
nano Run_SmallRNA_Pipeline.sh
# Change: ADAPTER_SEQUENCE="TGGAATTCTCGGGTGCCAAGG"  # Illumina TruSeq

# Run pipeline
bash Run_SmallRNA_Pipeline.sh
```

## Command-Line Options

### `--build-references`
Build genome references (Step 01). Only needed once per reference genome.

**When to use:**
- First time using the pipeline
- Switching to a different genome version
- References got corrupted or deleted

**Time:** ~2-4 hours

### `--skip-viz`
Skip coverage visualization (Step 06) to complete analysis faster.

**When to use:**
- Quick initial QC
- Re-processing samples where you already have coverage plots
- When you only need expression data

**Time saved:** ~4-8 hours

### `--help`
Display usage information and exit.

## Pipeline Stages

The script orchestrates 6 main stages:

| Stage | Script | Description | Time |
|-------|--------|-------------|------|
| **01** | `01_prepare_mouse_references.sh` | Build STAR/RSEM indices | 2-4h |
| **02-03** | `02_smRNA_analysis.sh` | Process each sample | 1-2h each |
| **04** | `04_rerun_rsem_all_samples.sh` | RSEM quantification batch | 12-24h |
| **05** | `05_run_emapper_all_samples.sh` | Generate BigWig coverage | 6-12h |
| **06** | `06_visualize_coverage.sh` | Coverage plots | 4-8h |

**Total time:** 24-48 hours (depends on sample count)

## Output Structure

```
OUTPUT_BASE_DIR/
├── SAMPLE1_output/
│   ├── 01_trimmed/              # Adapter-trimmed reads
│   ├── 02_aligned/              # BAM alignment files
│   ├── 03_counts/               # featureCounts + RSEM raw counts
│   ├── 04_expression/           # TPM matrices + plots
│   │   ├── *_RSEM_TPM.tsv                        # Full expression matrix
│   │   ├── *_miRNAs_only_RSEM.tsv               # miRNAs subset
│   │   ├── *_GeneType_Barplot.pdf               # Gene type counts
│   │   ├── *_RNA_distribution_2subplots.pdf     # RNA composition
│   │   └── *_top_expressed_genes.pdf            # Top 50 genes
│   ├── 05_qc/                   # FastQC reports
│   ├── 06_emapper/              # BigWig coverage files
│   ├── 07_coverage_plots/       # Coverage visualizations
│   │   ├── *_bed_density_heatmap.png
│   │   └── *_bed_stacked_profile_meta_gene.png
│   └── logs/                    # Per-sample logs
├── SAMPLE2_output/
│   └── ...
└── ...
```

## Monitoring

### Check Job Status

```bash
# View all your jobs
squeue -u $USER

# View specific pipeline jobs (use IDs from submission output)
sacct -j JOB_ID1,JOB_ID2,JOB_ID3 --format=JobID,JobName,State,Elapsed,MaxRSS
```

### Monitor Logs

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs

# Reference building
tail -f 01_build_refs_*.log

# Individual samples
tail -f 02_SAMPLE_NAME_*.log

# Batch steps
tail -f 04_rsem_batch_*.log
tail -f 05_emapper_*.log
tail -f 06_viz_*.log
```

### Check Progress

```bash
# Count completed samples
ls -d OUTPUT_BASE_DIR/*_output/04_expression/*_RSEM_TPM.tsv | wc -l

# Check which samples have BigWig files
ls OUTPUT_BASE_DIR/*_output/06_emapper/*.bw | wc -l

# Check visualization completion
ls OUTPUT_BASE_DIR/*_output/07_coverage_plots/*.png | wc -l
```

## Troubleshooting

### Error: Input directory not found

**Problem:**
```
ERROR: Input directory not found: /path/to/your/fastq/files
```

**Solution:** Edit `INPUT_FASTQ_DIR` in the script to point to your actual FASTQ directory.

### Error: No FASTQ files found

**Problem:**
```
ERROR: No FASTQ files found in /path/to/fastq
```

**Solution:** 
- Ensure files have `.fastq.gz` or `.fq.gz` extensions
- Check file permissions
- Verify the directory path is correct

### Error: References not found

**Problem:**
```
ERROR: References not found at /path/to/references
```

**Solution:** Run with `--build-references` first:
```bash
bash Run_SmallRNA_Pipeline.sh --build-references
```

### Job Dependencies Failed

**Problem:** Jobs show `DependencyNeverSatisfied` status

**Solution:**
1. Check if previous job failed: `sacct -j JOB_ID`
2. Review log files for the failed job
3. Fix the issue and resubmit

### Out of Memory Errors

**Problem:** Jobs fail with OOM (Out Of Memory) errors

**Solution:** Increase memory in configuration:
```bash
RSEM_BATCH_MEM="64G"  # Increase from 48G
EMAPPER_BATCH_MEM="64G"  # Increase from 48G
```

## Differences from Old Scripts

| Old Scripts | New Master Script | Benefit |
|-------------|-------------------|---------|
| `RUN_FULL_PIPELINE.sh` | Steps 04-05 in one script | Consolidated |
| `RUN_FULL_PIPELINE_WITH_VIZ.sh` | Steps 04-06 in one script | Consolidated |
| `RERUN_ALL_SAMPLES.sh` | Steps 02-03 in one script | Consolidated |
| Multiple config edits | Single config section | Easier to use |
| Manual dependency tracking | Automatic dependencies | No coordination needed |
| Scattered documentation | Integrated help | Self-documenting |

**Old scripts location:** `archive/old_orchestration_scripts/` (kept for reference)

## Best Practices

### 1. Test with One Sample First

```bash
# Move one FASTQ to test directory
mkdir /tmp/test_fastq
cp /path/to/sample.fastq.gz /tmp/test_fastq/

# Edit script to use test directory
nano Run_SmallRNA_Pipeline.sh
# Set INPUT_FASTQ_DIR="/tmp/test_fastq"

# Run pipeline
bash Run_SmallRNA_Pipeline.sh
```

### 2. Keep Configuration Documented

Save your configuration settings:
```bash
# At the top of the script, add comments:
# Analysis: Experiment ABC
# Date: 2026-02-17
# Kit: Takara SMARTer
# Samples: 35 mouse liver samples
```

### 3. Track Job IDs

The script creates `logs/pipeline_jobs_TIMESTAMP.txt` with all job IDs. Keep this for reference.

### 4. Regular Backups

```bash
# Backup results periodically
rsync -av OUTPUT_BASE_DIR/ /backup/location/
```

## Advanced Usage

### Different References for Different Projects

Create project-specific reference directories:

```bash
# In Run_SmallRNA_Pipeline.sh:
REFERENCE_DIR="/home/hmoka2/references/mouse_mm39"    # Project A
REFERENCE_DIR="/home/hmoka2/references/mouse_mm10"    # Project B (older assembly)
```

### Custom Resource Allocation

Adjust resources based on cluster load:

```bash
# Light cluster load - use more resources
RSEM_BATCH_CPUS=16
RSEM_BATCH_MEM="128G"

# Heavy cluster load - use less for faster scheduling
RSEM_BATCH_CPUS=8
RSEM_BATCH_MEM="48G"
```

### Process Samples in Batches

```bash
# Batch 1: Samples 1-10
mkdir batch1_fastq
mv samples_1-10*.fastq.gz batch1_fastq/
# Edit INPUT_FASTQ_DIR="/path/to/batch1_fastq"
bash Run_SmallRNA_Pipeline.sh

# Batch 2: Samples 11-20
mkdir batch2_fastq
mv samples_11-20*.fastq.gz batch2_fastq/
# Edit INPUT_FASTQ_DIR="/path/to/batch2_fastq"
bash Run_SmallRNA_Pipeline.sh
```

## FAQ

**Q: Can I run the script multiple times?**  
A: Yes, it skips already-processed samples automatically.

**Q: What if I need to add more samples later?**  
A: Just update `INPUT_FASTQ_DIR` to include new samples and run again.

**Q: Can I use a different genome (e.g., human)?**  
A: Yes, but you need to change `GENOME_URL` and `GTF_URL` in the configuration and rebuild references.

**Q: How do I cancel all jobs?**  
A: `scancel -u $USER` cancels all your jobs.

**Q: Where are the miRNA quantification results?**  
A: `OUTPUT_BASE_DIR/SAMPLE_output/04_expression/SAMPLE_miRNAs_only_RSEM.tsv`

**Q: Can I customize the number of top genes in plots?**  
A: Yes, edit `TOP_GENES_PER_TYPE` and `TOTAL_TOP_GENES` in the configuration.

## Related Documentation

- **QUICKSTART.md** - Basic pipeline usage
- **PIPELINE_OVERVIEW.md** - Pipeline structure and workflow
- **NEW_PLOTS_GUIDE.md** - Expression plot interpretation
- **VISUALIZATION_GUIDE.md** - Coverage plot details
- **SLURM_GUIDE.md** - SLURM-specific information

## Support

For issues:
1. Check log files in `logs/` directory
2. Review error messages in SLURM `.err` files
3. Consult troubleshooting section above
4. Check relevant documentation files

---

**Version:** 1.0  
**Date:** February 17, 2026  
**Status:** Production-ready
