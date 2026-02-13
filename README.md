# Mouse Small RNA-seq Analysis Pipeline

A robust, cluster-optimized pipeline for small RNA sequencing analysis in mouse (GRCm39/GENCODE M38), specifically designed for Takara SMARTer smRNA-Seq Kit data.

## Overview

This pipeline provides comprehensive analysis of small RNA sequencing data with a focus on miRNA detection and quantification. It uses standard RNA-seq quantification tools (featureCounts, RSEM) and generates publication-ready outputs including QC reports, expression matrices, and gene type distribution visualizations.

**Key Features:**
- ✅ Mouse genome (GRCm39/GENCODE M38) annotation
- ✅ Takara SMARTer smRNA-Seq adapter trimming
- ✅ SLURM cluster optimization
- ✅ Comprehensive QC and reporting
- ✅ miRNA-specific extraction and quantification
- ✅ Gene type distribution visualization
- ✅ TPM normalization
- ✅ Handles 2,201 annotated mouse miRNAs

---

## Quick Start

### 1. Clone Repository

```bash
git clone [your-repo-url]
cd mouse_smallRNA-pipeline
```

### 2. Prepare References (One-time Setup)

```bash
# Submit as SLURM job
sbatch 01_prepare_mouse_references.sh

# Or run interactively
bash 01_prepare_mouse_references.sh
```

**Resources:** 16 CPUs, 120GB RAM, ~2-3 hours  
**Output:** Creates `references/` directory (~31 GB) with genome, annotations, and indices

### 3. Analyze Single Sample

```bash
# Create output directory and logs
mkdir -p my_analysis/logs

# Submit job
sbatch 02_smRNA_analysis.sh sample_name /path/to/sample.fastq.gz

# Or run interactively
bash 02_smRNA_analysis.sh sample_name /path/to/sample.fastq.gz
```

**Resources:** 16 CPUs, 80GB RAM, ~1-2 min/sample

### 4. Batch Process Multiple Samples

```bash
# Create analysis directory
mkdir -p /path/to/analysis_dir
cd /path/to/analysis_dir

# Create symlinks to pipeline resources
ln -s /path/to/mouse_smallRNA-pipeline/references ./references
ln -s /path/to/mouse_smallRNA-pipeline/scripts ./scripts
mkdir -p logs

# Submit jobs for all samples
for fastq in /path/to/fastq_dir/*.fastq.gz; do
    sample=$(basename "$fastq" | sed 's/_R1_001.fastq.gz$//')
    sbatch --output="logs/smRNA_%j_${sample}.log" \
           --error="logs/smRNA_%j_${sample}.err" \
           /path/to/mouse_smallRNA-pipeline/02_smRNA_analysis.sh \
           "${sample}" "${fastq}"
done
```

See `SLURM_GUIDE.md` for detailed instructions.

---

## Pipeline Workflow

```
Input FASTQ
    ↓
[1] Adapter Trimming (cutadapt)
    ├─ Remove 3bp TSO (Template Switching Oligo)
    ├─ Trim polyA adapter sequence
    └─ Quality filtering (min length 15bp)
    ↓
[2] Quality Control (FastQC)
    └─ Generate QC reports
    ↓
[3] Genome Alignment (STAR)
    ├─ Small RNA optimized parameters
    ├─ No intron mapping (--alignIntronMax 1)
    └─ End-to-end alignment
    ↓
[4] Read Quantification
    ├─ featureCounts: Gene-level counts
    └─ RSEM: Isoform-level (optional)
    ↓
[5] TPM Normalization
    └─ Transcripts Per Million
    ↓
[6] miRNA Extraction
    ├─ Filter for miRNA gene type
    ├─ Identify top expressed miRNAs
    └─ Generate miRNA-specific tables
    ↓
[7] Gene Type Visualization
    ├─ Barplots of gene biotypes
    └─ Distribution analysis
    ↓
[8] Comprehensive Report
    └─ Analysis summary with all metrics
```

---

## Output Structure

Each sample generates organized results:

```
{sample}_output/
├── 01_trimmed/
│   ├── {sample}_trimmed.fq.gz              # Adapter-trimmed reads
│   └── {sample}_trimming_report.txt        # Trimming statistics
├── 02_aligned/
│   ├── {sample}_Aligned.sortedByCoord.out.bam  # Sorted BAM
│   ├── {sample}_Log.final.out              # STAR alignment stats
│   └── {sample}_Log.out                    # Detailed STAR log
├── 03_counts/
│   ├── {sample}_featureCounts.txt          # featureCounts output
│   ├── {sample}_featureCounts.txt.summary  # Count summary
│   └── {sample}_RSEM.genes.results         # RSEM output (optional)
├── 04_expression/
│   ├── {sample}_featureCounts_TPM.tsv      # TPM normalized counts
│   ├── {sample}_miRNAs_only_featureCounts.tsv  # miRNA subset
│   ├── {sample}_GeneType_Barplot.pdf       # Gene type visualization
│   └── {sample}_RSEM_TPM.tsv               # RSEM TPM (if available)
├── 05_qc/
│   ├── {sample}_trimmed_fastqc.html        # FastQC HTML report
│   └── {sample}_trimmed_fastqc.zip         # FastQC data archive
├── logs/                                    # Step-specific logs
└── {sample}_ANALYSIS_SUMMARY.txt           # Comprehensive summary
```

---

## Key Pipeline Features

### Adapter Trimming (Takara SMARTer smRNA-Seq)

```bash
cutadapt -u 3                    # Remove 3bp TSO
         -a AAAAAAAAAA           # Trim polyA-based adapter
         -m 15                   # Minimum length 15bp
         --poly-a                # Additional polyA trimming
         -j 16                   # 16 threads
```

### STAR Alignment (Small RNA Optimized)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `--alignIntronMax` | 1 | Small RNAs lack introns |
| `--alignEndsType` | EndToEnd | Full read must align |
| `--outFilterMismatchNmax` | 2 | Max 2 mismatches |
| `--outFilterMatchNmin` | 16 | Min 16bp match |
| `--outFilterMatchNminOverLread` | 0.9 | 90% of read must match |
| `--sjdbOverhang` | 69 | Read length - 1 |

### Quantification Methods

**featureCounts (Primary):**
- Multi-mapping handling with fractional counting (`-M --fraction`)
- Strand-specific counting (`-s 1`)
- Gene-level quantification
- Reliable for small RNA-seq

**RSEM (Optional):**
- Expectation-Maximization algorithm
- Handles multi-mapping reads probabilistically
- May fail due to samtools bgzf bug (pipeline handles gracefully)

---

## Mouse miRNA Statistics (GENCODE M38)

| Category | Count | Percentage |
|----------|-------|------------|
| **Total miRNAs** | 2,201 | 100% |
| Canonical (Mir*) | 1,189 | 54.0% |
| Predicted (Gm*) | 1,012 | 46.0% |

**Typical Detection Rate:** 10-20% of annotated miRNAs per sample
- Depends on tissue type, sequencing depth, RNA quality
- Range observed: 165-437 miRNAs per sample
- High biological variability is normal and expected

---

## System Requirements

### Software Dependencies

**Cluster Modules:**
- STAR 2.7.11a
- RSEM 1.3.3
- Subread (featureCounts) 2.0.6
- FastQC 0.12.1
- samtools 1.17

**Conda Environment (smallrna-tools):**
- Python 3.9+
- cutadapt 4.9
- pandas
- matplotlib
- numpy

### Compute Resources

| Step | CPUs | Memory | Time | Partition |
|------|------|--------|------|-----------|
| Reference prep | 16 | 120 GB | 2-3 h | cpu |
| Per-sample analysis | 16 | 80 GB | 1-2 min | cpu |
| Batch processing | 16/job | 80 GB/job | Parallel | cpu |

### Storage Requirements

- **References:** ~31 GB (genome + indices)
- **Per sample:** ~500 MB - 2 GB (depth-dependent)
- **Batch analysis:** Plan accordingly for N samples

---

## Installation & Setup

### 1. Clone Repository

```bash
cd /path/to/your/workspace
git clone [repository-url] mouse_smallRNA-pipeline
cd mouse_smallRNA-pipeline
```

### 2. Load Required Modules

The pipeline automatically loads required modules via `load_modules.sh`:

```bash
# Modules loaded automatically:
# - star/2.7.11a-pgsk3s4
# - rsem/1.3.3
# - subread/2.0.6
# - fastqc/0.12.1
# - samtools/1.17-xtpk2gu

# Conda environment: smallrna-tools
```

### 3. Prepare References (First Time Only)

```bash
sbatch 01_prepare_mouse_references.sh
```

This downloads and builds:
- GRCm39 genome (GENCODE)
- GENCODE M38 gene annotations
- STAR genome indices
- RSEM transcriptome indices
- Gene metadata table

---

## Usage Examples

### Example 1: Single Sample Interactive Run

```bash
# Load environment
source load_modules.sh

# Run analysis
bash 02_smRNA_analysis.sh MySample /data/MySample_R1_001.fastq.gz

# Check results
cat MySample_output/MySample_ANALYSIS_SUMMARY.txt
less MySample_output/04_expression/MySample_miRNAs_only_featureCounts.tsv
```

### Example 2: SLURM Batch Submission

```bash
# Create project directory
mkdir -p /path/to/project/analysis
cd /path/to/project/analysis

# Setup
ln -s /path/to/mouse_smallRNA-pipeline/references ./references
ln -s /path/to/mouse_smallRNA-pipeline/scripts ./scripts
mkdir -p logs

# Batch submit
for fq in /data/fastq_dir/*.fastq.gz; do
    name=$(basename "$fq" .fastq.gz)
    sbatch \
        --output="logs/${name}_%j.log" \
        --error="logs/${name}_%j.err" \
        /path/to/mouse_smallRNA-pipeline/02_smRNA_analysis.sh \
        "$name" "$fq"
done

# Monitor jobs
squeue -u $USER
watch -n 10 'squeue -u $USER'
```

### Example 3: Check Results Across Samples

```bash
# Count detected miRNAs per sample
for dir in *_output; do
    sample=$(basename "$dir" _output)
    count=$(grep -v "^GeneID" "$dir/04_expression/${sample}_miRNAs_only_featureCounts.tsv" | wc -l)
    echo "$sample: $count miRNAs"
done

# View gene type plots
ls *_output/04_expression/*_GeneType_Barplot.pdf
```

---

## Known Issues & Solutions

### Issue 1: RSEM bgzf Compression Failure

**Symptom:**
```
samtools: bgzf.c:218: bgzf_hopen: Assertion 'compressBound(BGZF_BLOCK_SIZE) < BGZF_MAX_BLOCK_SIZE' failed
```

**Cause:** Incompatibility between samtools (compiled with zlib-ng) and bgzf compression

**Impact:** RSEM quantification fails

**Solution:** Pipeline handles this gracefully and continues with featureCounts results (which are accurate and sufficient for most analyses)

### Issue 2: FIFO File Creation Error

**Symptom:**
```
STAR: *FATAL ERROR*: could not create FIFO file
```

**Cause:** Network filesystems may not support FIFO files

**Solution:** Run analysis in local storage (e.g., `/home/user/local/`) rather than network mounts

### Issue 3: Reference Directory Not Found

**Cause:** Pipeline script executed from different directory than expected

**Solution:** Create symlinks in your working directory:
```bash
ln -s /path/to/mouse_smallRNA-pipeline/references ./references
ln -s /path/to/mouse_smallRNA-pipeline/scripts ./scripts
```

---

## Frequently Asked Questions

**Q: Why are only 10-20% of annotated miRNAs detected?**  
A: This is normal. miRNAs are highly tissue-specific and many predicted miRNAs have low/no expression.

**Q: Why does RSEM fail but the pipeline continues?**  
A: The bgzf bug is a known issue. featureCounts provides accurate quantification for small RNA-seq.

**Q: Can I run without SLURM?**  
A: Yes, remove the `#SBATCH` headers and run scripts directly with `bash script.sh ...`

**Q: How do I analyze samples from different conditions?**  
A: Run each sample through the pipeline, then use downstream tools (DESeq2, edgeR) for differential expression analysis.

**Q: What if my adapters are different?**  
A: Modify the `cutadapt` command in `02_smRNA_analysis.sh` to match your library preparation kit.

---

## Citation

If you use this pipeline, please cite:

1. **GENCODE:** Frankish et al. (2021) GENCODE 2021. *Nucleic Acids Research*. 49:D916-D923
2. **STAR:** Dobin et al. (2013) STAR: ultrafast universal RNA-seq aligner. *Bioinformatics*. 29(1):15-21
3. **RSEM:** Li & Dewey (2011) RSEM: accurate transcript quantification from RNA-Seq data. *BMC Bioinformatics*. 12:323
4. **featureCounts:** Liao et al. (2014) featureCounts: an efficient general purpose program for assigning sequence reads to genomic features. *Bioinformatics*. 30(7):923-930
5. **Cutadapt:** Martin (2011) Cutadapt removes adapter sequences from high-throughput sequencing reads. *EMBnet.journal*. 17(1):10-12

---

## Documentation

- **README.md** (this file) - Overview and quick start
- **QUICKSTART.md** - Step-by-step getting started guide
- **SLURM_GUIDE.md** - Detailed SLURM cluster usage
- **Methodology_readme.md** - Detailed methodology and pipeline rationale

---

## Support

For issues, questions, or contributions:
- Check the documentation files
- Review log files in `{sample}_output/logs/`
- Check SLURM logs in `logs/` directory

---

## Version History

**v1.0** (February 2026)
- Initial release
- Mouse GRCm39/GENCODE M38 support
- Takara SMARTer smRNA-Seq adapter handling
- SLURM cluster optimization
- Gene type barplot generation
- Comprehensive error handling
- miRNA-specific extraction

---

## License

MIT License - See LICENSE file for details

---

## Acknowledgments

Pipeline design inspired by standard RNA-seq best practices and optimized for small RNA sequencing analysis. Special focus on miRNA detection and quantification in mouse models.

**Development:** [Your name/institution]  
**Date:** February 2026  
**Contact:** [Your email]
