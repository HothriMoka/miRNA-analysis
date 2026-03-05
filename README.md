# Mouse Small RNA-seq Analysis Pipeline

A complete, automated pipeline for mouse small RNA sequencing data analysis with a focus on miRNA quantification and quality control.

## Overview

This pipeline processes small RNA-seq data from raw FASTQ files through alignment, quantification, and visualization. It uses RSEM's EM algorithm for accurate miRNA quantification and generates comprehensive quality control plots.

**Compatible with:** All small RNA-seq library prep kits (adapter configurable)  
**Genome:** Mouse GRCm39 (GENCODE vM38)  
**Compute:** SLURM cluster with automatic job dependencies  

## Quick Start

### 1. Edit Configuration

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline
nano Run_SmallRNA_Pipeline.sh
```

Edit these lines at the top:

```bash
# Where your FASTQ files are
INPUT_FASTQ_DIR="/path/to/your/fastq/files"

# Where to save results
OUTPUT_BASE_DIR="/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA"

# ⚠️ IMPORTANT: Set the adapter for YOUR library prep kit!
ADAPTER_SEQUENCE="AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"  # Illumina TruSeq (most common)

# Other options provided in the script:
# - NEBNext Small RNA:        AGATCGGAAGAGCACACGTCT
# - Takara SMARTer:           AAAAAAAAAA
# - QIAseq miRNA:             AACTGTAGGCACCATCAAT
# - Illumina Small RNA v1.5:  TGGAATTCTCGGGTGCCAAGG
```

### 2. First Time: Build References

```bash
bash Run_SmallRNA_Pipeline.sh --build-references
```

⚠️ **Important:** Use `bash`, NOT `sbatch`! This script orchestrates job submissions.

This downloads the mouse genome and builds indices (~2-4 hours, only needed once).

### 3. Process Your Samples

```bash
bash Run_SmallRNA_Pipeline.sh
```

⚠️ **Important:** Use `bash`, NOT `sbatch`!

That's it! The pipeline will automatically:
- Process all FASTQ files in your input directory
- Run RSEM quantification
- Generate BigWig coverage files
- Create quality control plots
- Handle all job dependencies

## What You Get

For each sample, the pipeline generates:

```
SAMPLE_NAME_output/
├── 04_expression/
│   ├── SAMPLE_RSEM_TPM.tsv                      # Expression matrix (all genes)
│   ├── SAMPLE_miRNAs_only_RSEM.tsv             # miRNA subset ⭐
│   ├── SAMPLE_GeneType_Barplot.pdf             # Gene type distribution
│   ├── SAMPLE_RNA_distribution_2subplots.pdf   # RNA composition analysis
│   └── SAMPLE_top_expressed_genes.pdf          # Top 50 genes (QC)
├── 06_emapper/
│   └── SAMPLE_final_unstranded.bw              # Coverage track (IGV)
└── 07_coverage_plots/
    ├── SAMPLE_bed_density_heatmap.png          # Coverage over RNA types
    └── SAMPLE_bed_stacked_profile_meta_gene.png # Meta-gene profile
```

**Most important file:** `SAMPLE_miRNAs_only_RSEM.tsv` - miRNA quantification in TPM

## Adapter Sequences

Change `ADAPTER_SEQUENCE` in `Run_SmallRNA_Pipeline.sh` for your kit:

| Library Prep Kit | Adapter Sequence |
|-----------------|------------------|
| **Takara SMARTer** (default) | `AAAAAAAAAA` |
| Illumina TruSeq Small RNA | `TGGAATTCTCGGGTGCCAAGG` |
| NEBNext Small RNA | `AGATCGGAAGAGCACACGTCT` |
| QIAseq miRNA | `AACTGTAGGCACCATCAAT` |

## Pipeline Steps

The pipeline runs 6 steps automatically:

1. **Build References** (optional, one-time) - Download genome & build indices
2. **Process Samples** - Trim, align, QC for each FASTQ file
3. **RSEM Quantification** - EM-based miRNA quantification
4. **EMapper** - Generate BigWig coverage files
5. **Visualization** - Coverage density plots
6. **QC Plots** - Expression analysis plots

All jobs are submitted with automatic dependencies - you don't need to monitor completion.

## Monitoring

### Check Job Status

```bash
# View all your jobs
squeue -u $USER

# Check specific jobs (use IDs from submission output)
sacct -j JOB_ID1,JOB_ID2 --format=JobID,JobName,State,Elapsed
```

### View Logs

```bash
cd OUTPUT_DIR/logs/

# Individual samples
tail -f 02_SAMPLE_NAME_*.log

# Batch steps
tail -f 04_rsem_batch_*.log
tail -f 05_emapper_*.log
tail -f 06_viz_*.log
```

All logs from the master script are saved in `OUTPUT_DIR/logs/` (keeps pipeline directory clean).

### Check Progress

```bash
# Count processed samples
ls OUTPUT_DIR/*_output/04_expression/*_RSEM_TPM.tsv | wc -l

# Check which samples completed
ls -d OUTPUT_DIR/*_output/04_expression/ | xargs -n1 basename | sed 's/_output//'
```

## Quality Control

Use the generated plots to assess sample quality:

### 1. Top Expressed Genes Plot
**File:** `SAMPLE_top_expressed_genes.pdf`

**Good sample:**
- Multiple miRNAs in top 20 genes
- Diverse gene types
- No single gene >20% of expression

**Warning signs:**
- rRNA genes (Rn45s, Rn18s, Rn28s) in top 5 → Poor rRNA depletion
- Mitochondrial genes (Mt-rnr1, Mt-rnr2) in top 10 → Contamination
- Hemoglobin genes (Hba, Hbb) → Blood contamination

### 2. RNA Distribution Plot
**File:** `SAMPLE_RNA_distribution_2subplots.pdf`

**Good sample:**
- miRNAs dominate at TPM > 1
- rRNA < 10% at higher thresholds

**Warning signs:**
- rRNA > 30% → Poor library quality
- protein_coding dominates → Wrong library type

### 3. Coverage Plots
**Files:** `SAMPLE_bed_density_heatmap.png`, `SAMPLE_bed_stacked_profile_meta_gene.png`

**Good sample:**
- Strong miRNA signal in heatmap
- Uniform coverage in meta-gene plot

## Common Options

### Skip Visualization (Faster)

```bash
bash Run_SmallRNA_Pipeline.sh --skip-viz
```

Saves ~4-8 hours if you don't need coverage plots.

### Process Additional Samples

Just update `INPUT_FASTQ_DIR` to point to new FASTQ files and run again:

```bash
nano Run_SmallRNA_Pipeline.sh  # Update INPUT_FASTQ_DIR
bash Run_SmallRNA_Pipeline.sh   # Process new samples
```

Already-processed samples are automatically skipped.

### Different Library Kit

```bash
nano Run_SmallRNA_Pipeline.sh
# Change: ADAPTER_SEQUENCE="TGGAATTCTCGGGTGCCAAGG"  # For Illumina
bash Run_SmallRNA_Pipeline.sh
```

## Troubleshooting

### Error: Permission denied creating logs

**Cause:** You ran the script with `sbatch` instead of `bash`

**Fix:** Use `bash` to run the master script:
```bash
bash Run_SmallRNA_Pipeline.sh
```

**NOT** `sbatch Run_SmallRNA_Pipeline.sh` ❌

The master script is an orchestrator that submits jobs - it should not itself be submitted as a job.

### Error: Input directory not found

**Fix:** Edit `INPUT_FASTQ_DIR` in `Run_SmallRNA_Pipeline.sh` to point to your FASTQ directory.

### Error: No FASTQ files found

**Check:**
- Files have `.fastq.gz` or `.fq.gz` extensions
- You have read permissions
- Path is correct

### Error: References not found

**Fix:** Run with `--build-references` first:
```bash
bash Run_SmallRNA_Pipeline.sh --build-references
```

### Job Fails with "DependencyNeverSatisfied"

**Cause:** Previous job in chain failed

**Fix:**
1. Check which job failed: `sacct -j JOB_ID`
2. Read its log file in `logs/`
3. Fix the issue and resubmit

### Out of Memory Errors

**Fix:** Increase memory in `Run_SmallRNA_Pipeline.sh`:
```bash
RSEM_BATCH_MEM="64G"    # Increase from 48G
EMAPPER_BATCH_MEM="64G"  # Increase from 48G
```

## Resource Requirements

| Step | CPUs | Memory | Time (35 samples) |
|------|------|--------|-------------------|
| Reference building | 16 | 120GB | 2-4 hours |
| Sample processing | 8 | 48GB | 1-2 hours each |
| RSEM batch | 8 | 48GB | 12-24 hours |
| EMapper batch | 8 | 48GB | 6-12 hours |
| Visualization | 4 | 16GB | 4-8 hours |

**Total time:** ~24-48 hours for complete analysis of 35 samples

## Software & Dependencies

**Cluster modules:**
- STAR 2.7.11a
- subread 2.0.6 (featureCounts)
- FastQC 0.12.1

**Conda environment:** `smallrna-tools`
- Python 3.9+
- RSEM 1.3.1 (fixed version with zlib-ng 2.2.5)
- samtools 1.22.1
- cutadapt 5.2
- pyBigWig, numba, pysam, psutil
- deepTools 3.5.6 (for visualization)
- matplotlib, numpy, pandas

## File Structure

```
mouse_smallRNA-pipeline/
├── Run_SmallRNA_Pipeline.sh           # ⭐ Master script - start here
├── 01_prepare_mouse_references.sh     # Build genome indices
├── 02_smRNA_analysis.sh               # Process single sample
├── 04_rerun_rsem_all_samples.sh       # RSEM quantification (batch)
├── 05_run_emapper_all_samples.sh      # Generate BigWig files (batch)
├── 06_visualize_coverage.sh           # Coverage plots (batch)
├── scripts/                           # Python/shell helper scripts
├── references/                        # Genome, annotations, indices
└── docs/                              # Detailed documentation

OUTPUT_DIR/                            # Your output location
├── logs/                              # SLURM job logs (from master script)
└── SAMPLE_output/                     # Per-sample results
```

## Citation

If you use this pipeline, please cite:

- **STAR:** Dobin et al., Bioinformatics 2013
- **RSEM:** Li & Dewey, BMC Bioinformatics 2011
- **GENCODE:** Frankish et al., Nucleic Acids Res 2021
- **deepTools:** Ramírez et al., Nucleic Acids Res 2016

## Advanced Usage

### Custom Resource Allocation

Edit resource settings in `Run_SmallRNA_Pipeline.sh`:

```bash
# === RESOURCE ALLOCATION ===
RSEM_BATCH_CPUS=16        # Increase for faster processing
RSEM_BATCH_MEM="128G"     # Increase if out-of-memory
RSEM_BATCH_TIME="48:00:00" # Increase if timing out
```

### Different Genome/Organism

1. Edit URLs in `Run_SmallRNA_Pipeline.sh`:
```bash
GENOME_URL="https://path/to/genome.fa.gz"
GTF_URL="https://path/to/annotation.gtf.gz"
```

2. Rebuild references:
```bash
bash Run_SmallRNA_Pipeline.sh --build-references
```

### Run Individual Scripts

You can still run scripts independently:

```bash
# Process one sample
bash 02_smRNA_analysis.sh SAMPLE input.fastq.gz --threads 8 --adapter AAAA

# Run RSEM batch only
sbatch 04_rerun_rsem_all_samples.sh

# Run EMapper only
sbatch 05_run_emapper_all_samples.sh
```

## Getting Help

### Documentation

- **This README:** General usage and quick start
- **`docs/MASTER_SCRIPT_GUIDE.md`:** Complete master script reference
- **`docs/detailed/`:** Technical documentation and troubleshooting

### Check Logs

Most issues can be diagnosed from log files:

```bash
# SLURM job logs
ls logs/*.log

# Pipeline-specific logs
ls OUTPUT_DIR/SAMPLE_output/logs/*.log

# Coverage plot logs
ls OUTPUT_DIR/SAMPLE_output/07_coverage_plots/*.log
```

### Common Log Locations

All logs are in: `OUTPUT_DIR/logs/`

- **Reference building:** `01_build_refs_*.log`
- **Sample processing:** `02_SAMPLE_*.log`
- **RSEM batch:** `04_rsem_batch_*.log`
- **EMapper:** `05_emapper_*.log`
- **Visualization:** `06_viz_*.log`

Individual scripts also create per-sample logs in: `SAMPLE_output/logs/`

## Key Features

✅ **Single command execution** - Run entire pipeline with one command  
✅ **Automatic dependencies** - No manual job coordination needed  
✅ **Smart skipping** - Already-processed samples are skipped  
✅ **EM-based quantification** - Proper handling of multi-mapping miRNAs  
✅ **Comprehensive QC** - Multiple quality control plots  
✅ **Easy configuration** - All settings in one place  
✅ **Adapter flexibility** - Easy to change for different kits  
✅ **Coverage visualization** - BigWig files + deepTools plots  
✅ **Latest annotations** - GRCm39/GENCODE vM38 (Sept 2025)  

## Pipeline Outputs Explained

### Expression Files

**`SAMPLE_RSEM_TPM.tsv`** - All genes with columns:
- `GeneID`: Ensembl gene ID
- `GeneSymbol`: Gene name
- `GeneType`: Gene biotype (miRNA, protein_coding, etc.)
- `ReadCounts`: Raw read counts
- `TPM`: Transcripts Per Million (normalized)

**`SAMPLE_miRNAs_only_RSEM.tsv`** - Filtered to miRNAs only

### Coverage Files

**`SAMPLE_final_unstranded.bw`** - BigWig coverage track
- Load in IGV or UCSC Genome Browser
- Shows read coverage across genome
- Single-base resolution

### QC Plots

**Gene Type Barplot** - Bar chart showing counts and percentages of each gene type

**RNA Distribution** - 4-panel plot comparing:
- Top: Expression-weighted (TPM) filtering
- Bottom: Count-based filtering
- Shows how RNA composition changes with thresholds

**Top Expressed Genes** - Horizontal bar plot of 50 most abundant genes
- Colored by gene type
- Helps identify contamination or problems

**Coverage Heatmap** - Shows read coverage distribution across RNA types

**Meta-gene Profile** - Shows average coverage from TSS to TES

## Version Info

**Pipeline Version:** 2.0  
**Last Updated:** February 17, 2026  
**Genome:** GRCm39 (mm39)  
**Annotations:** GENCODE vM38  
**Tested on:** SLURM cluster with cpu/hmem/nice partitions  

## Acknowledgments

**Development:** Hothri Moka  
**Date:** February 2026  

**For detailed documentation, see `docs/` directory**  
**For troubleshooting, check log files first, then see `docs/MASTER_SCRIPT_GUIDE.md`**
