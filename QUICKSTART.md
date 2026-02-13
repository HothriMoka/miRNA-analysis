# Quick Start Guide - Mouse Small RNA-seq Pipeline

## ✅ Pipeline Status: READY TO RUN

All software validated and working!

---

## 🚀 Quick Start

### Option A: SLURM Cluster (Recommended)

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/mouse_smRNA_pipeline

# 1. Build references (submit as SLURM job, ~1-2 hours)
sbatch 01_prepare_mouse_references.sh

# 2. Check job status
squeue -u $USER

# 3. Once complete, submit all samples as separate jobs (PARALLEL)
./submit_batch_jobs.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5 \
  --threads 16 --mem 48G

# OR submit with dependency (automatically waits for references)
./submit_batch_jobs.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5 \
  --dependency
```

### Option B: Interactive/Direct Execution

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/mouse_smRNA_pipeline

# 1. Load environment
module load star/2.7.11a rsem/1.3.3 subread/2.0.6 fastqc/0.12.1 samtools
source $(conda info --base)/etc/profile.d/conda.sh
conda activate smallrna-tools

# 2. Build references (First Time Only, ~1-2 hours)
./01_prepare_mouse_references.sh 20

# 3. Run single sample
./02_smRNA_analysis.sh 204925 \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5/204925_S1_R1_001.fastq.gz \
  --threads 16

# 4. Or batch process all samples (sequential)
./03_batch_process.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5 \
  --threads 16
```

---

## 📊 Expected Output

For each sample `SAMPLE_NAME`:

```
SAMPLE_NAME_output/
├── SAMPLE_NAME_ANALYSIS_SUMMARY.txt        ⭐ START HERE
├── 04_expression/
│   ├── SAMPLE_NAME_miRNAs_only_RSEM.tsv    ⭐ miRNA RESULTS
│   └── SAMPLE_NAME_RSEM_TPM.tsv            (all genes)
├── 05_qc/
│   └── SAMPLE_NAME_trimmed_fastqc.html     (QC report)
└── logs/
    └── SAMPLE_NAME_pipeline.log            (full log)
```

### Top miRNA Results Preview

The pipeline will show:
```
Top 10 most abundant miRNAs (by RSEM TPM):
  Mir21a               12345.67 TPM
  Mir22                8432.21 TPM
  Mir26a-1             7234.56 TPM
  ...
```

---

## ⏱️ Time Estimates

| Step | Interactive | SLURM Jobs | Notes |
|------|-------------|------------|-------|
| **Reference building** | 1.5-2 hours | 1.5-2 hours | Once only (16 CPUs) |
| **Single sample** | 30-60 min | 30-60 min | Depends on read count |
| **6 samples (sequential)** | 3-6 hours | 3-6 hours | One after another |
| **6 samples (SLURM parallel)** | N/A | 30-60 min | ⭐ All run simultaneously |

**SLURM parallel is FASTEST** - all 6 samples complete in ~1 hour!

**Note:** Pipeline configured for `cpu` partition limits (16 CPUs max, 250GB memory, 3 days max time)

---

## 🔍 Validation Tests

Already done! Results:
- ✅ All scripts present and executable
- ✅ All required software available:
  - Python 3.9 with pandas, numpy
  - Cutadapt 5.2
  - FastQC 0.12.1
  - STAR 2.7.10b
  - Samtools 1.22.1
  - featureCounts (subread 2.0.6)
  - RSEM 1.3.1
- ✅ 6 test FASTQ files found
- ✅ System resources adequate (62GB RAM, 27TB disk)

---

## 🐛 Troubleshooting

### Q: "Command not found" errors
**A:** Reload environment:
```bash
module load star/2.7.11a rsem/1.3.3 subread/2.0.6 fastqc/0.12.1 samtools
conda activate smallrna-tools
```

### Q: Reference building out of memory
**A:** STAR indexing needs ~50-60GB RAM. Your system has 62GB - should work, but:
- Close other applications
- Or request high-memory node: `srun --mem=100G`

### Q: Low alignment rate (<50%)
**A:** Check:
1. Correct species (mouse, not human)
2. Adapters trimmed correctly (view FastQC report)
3. Read quality (view `05_qc/` reports)

### Q: No miRNAs detected
**A:** After reference building, verify:
```bash
grep -c "gene_type \"miRNA\"" references/annotations/gencode.vM38.annotation.gtf
# Should return >1000
```

---

## 📝 Key Files

### Must Read First
- `SAMPLE_NAME_ANALYSIS_SUMMARY.txt` - Complete analysis summary

### miRNA Results
- `04_expression/SAMPLE_NAME_miRNAs_only_RSEM.tsv` - **Use this for miRNA quantification**
  - Format: `GeneID | GeneSymbol | GeneType | ReadCounts | TPM`
  - Sorted by abundance
  - RSEM uses EM algorithm for multi-mapping reads (best for miRNA families)

### Quality Control
- `05_qc/SAMPLE_NAME_trimmed_fastqc.html` - HTML report with charts
- `01_trimmed/SAMPLE_NAME_cutadapt_report.txt` - Trimming statistics
- `02_aligned/SAMPLE_NAME_Log.final.out` - STAR alignment statistics

---

## 🔬 Correct Adapter Trimming

This pipeline uses **Takara SMARTer smRNA-Seq Kit** adapters:

```bash
cutadapt \
  -u 3 \                    # Remove 3bp TSO from 5' end
  -a AAAAAAAAAA \           # Trim polyA tail + adapters
  -m 15 \                   # Min length 15bp
  --nextseq-trim 20         # NextSeq quality trim
```

**Different from:**
- ❌ Standard Illumina adapters (34bp)
- ❌ EVscope Total RNA adapters (13bp)
- ✅ Correct for your SMARTer smRNA-Seq data

---

## 📧 Support

For issues:
1. Check `logs/SAMPLE_NAME_pipeline.log`
2. Re-run validation: `./00_validate_setup.sh`
3. See full README: `less README.md`

---

## 🎯 What's Next?

After pipeline completes:

1. **Check Summary:**
   ```bash
   cat 204925_output/204925_ANALYSIS_SUMMARY.txt
   ```

2. **View Top miRNAs:**
   ```bash
   head -20 204925_output/04_expression/204925_miRNAs_only_RSEM.tsv
   ```

3. **Compare Samples:**
   - Merge all `*_miRNAs_only_RSEM.tsv` files
   - Run differential expression (DESeq2, edgeR)
   - Create heatmaps and PCA plots

4. **Further Analysis:**
   - miRNA target prediction (TargetScan, miRDB)
   - Pathway enrichment (DIANA-miRPath, miRWalk)
   - isomiR analysis (if needed, requires different tools)

---

## ✨ Pipeline Features

- ✅ Latest mouse genome (GRCm39, GENCODE M38 - Sept 2025)
- ✅ Correct Takara SMARTer smRNA-Seq adapter trimming
- ✅ RSEM with EM algorithm (handles miRNA families properly)
- ✅ Automatic miRNA extraction and ranking
- ✅ Comprehensive QC and logging
- ✅ Batch processing with parallel option
- ✅ Human-readable summary reports

---

**Ready to start? Run Step 1 above! 🚀**
