# Log Files Location Guide

## 📁 Complete Log File Structure

### 1. SLURM Job Logs (Batch Submission Logs)

**Location**: `/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/`

**Files**:
```
smRNA_rerun_[SAMPLE]_[JOB_ID].log    # Standard output for sample jobs
smRNA_rerun_[SAMPLE]_[JOB_ID].err    # Error output for sample jobs
emapper_all_[JOB_ID].log             # EMapper batch job output
emapper_all_[JOB_ID].err             # EMapper batch job errors
```

**Examples**:
```bash
# Sample processing logs
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/smRNA_rerun_204914_S9_900453.log
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/smRNA_rerun_204915_S11_900454.log

# Current EMapper batch job
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/emapper_all_900491.log
```

### 2. Per-Sample Pipeline Logs

**Location**: `/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/logs/`

**Files**:
```
[SAMPLE]_pipeline.log        # Main pipeline log - ALL steps timestamped
star_align.log              # STAR alignment detailed output
rsem.log                    # RSEM quantification detailed output
featureCounts.log           # featureCounts quantification output
fastqc.log                  # FastQC quality control output
rsem_to_tpm.log            # RSEM to TPM matrix conversion
fc_to_tpm.log              # featureCounts to TPM conversion
barplot.log                # Gene type barplot generation
```

**Example for sample 204914_S9**:
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204914_S9_output/logs/

# Main log with all steps
cat 204914_S9_pipeline.log

# Check RSEM step
cat rsem.log

# Check STAR alignment
cat star_align.log
```

### 3. EMapper Per-Sample Logs

**Location**: `/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/06_emapper/`

**Files**:
```
[SAMPLE]_EMapper.log        # EMapper EM algorithm log
```

**Example**:
```bash
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204914_S9_output/06_emapper/204914_S9_EMapper.log
```

### 4. Pipeline Script Logs (Development/Testing)

**Location**: `/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/`

**Files**:
```
rsem_rerun_all_[JOB_ID].log      # RSEM batch script logs (not used in current run)
emapper_all_[JOB_ID].log         # EMapper batch script logs
prep_refs_[JOB_ID].log           # Reference preparation logs
*.err                            # Error logs
```

## 🔍 How to Find Specific Information

### Check if a Sample Completed Successfully
```bash
# Look for "Pipeline completed successfully" message
tail -20 /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/logs/[SAMPLE]_pipeline.log

# Or check the summary report
cat /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/[SAMPLE]_ANALYSIS_SUMMARY.txt
```

### Check RSEM Quantification Details
```bash
# Per-sample RSEM log
cat /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/logs/rsem.log

# Check if RSEM succeeded
grep -i "done\|error\|failed" /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/[SAMPLE]_output/logs/rsem.log | tail -5
```

### Check EMapper Progress (Current Job: 900491)
```bash
# Watch EMapper batch job progress
tail -f /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/emapper_all_900491.log

# Or from mouse_miRNA logs directory
tail -f /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/emapper_all_900491.log

# Check which sample EMapper is currently processing
grep "Processing:" /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/emapper_all_900491.log | tail -3
```

### Check for Errors Across All Samples
```bash
# Search for error messages in all sample pipeline logs
grep -i "error\|failed" /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/logs/*_pipeline.log

# Check SLURM error logs
ls -lh /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/*.err
cat /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/*.err | grep -v "^$"
```

### Count Completed Outputs
```bash
# Count samples with RSEM results
ls /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/03_counts/*_RSEM.genes.results 2>/dev/null | wc -l

# Count samples with transcriptome BAMs
ls /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/02_aligned/*toTranscriptome* 2>/dev/null | wc -l

# Count samples with BigWig files (after EMapper completes)
ls /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/06_emapper/*.bw 2>/dev/null | wc -l
```

## 📊 Current Run Status (Feb 16, 2026 17:18)

### Completed:
- ✅ All 35 samples: RSEM quantification complete
- ✅ All 35 samples: Transcriptome BAMs generated
- ✅ All 35 samples: miRNA-specific results available

### In Progress:
- 🔄 Job 900491: EMapper running on all 35 samples
- Expected completion: ~6-10 hours (around 11 PM - 3 AM)

### Key Logs to Monitor:
```bash
# Main EMapper progress
tail -f /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/emapper_all_900491.log

# Alternative path
tail -f /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/logs/emapper_all_900491.log

# Check job status
watch -n 30 'squeue -j 900491 && echo "" && grep "Processing:" /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/emapper_all_900491.log | tail -5'
```

## 🎯 Quick Reference Commands

```bash
# Check how many samples have BigWig files
watch -n 60 'ls /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/06_emapper/*.bw 2>/dev/null | wc -l'

# Monitor EMapper progress by counting completed samples
watch -n 60 'ls -d /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/06_emapper 2>/dev/null | wc -l'

# Check if EMapper job is still running
squeue -j 900491

# View EMapper progress
tail -50 /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline/logs/emapper_all_900491.log
```

## 📝 After EMapper Completes

Verify all outputs:
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA

for dir in *_output; do
    sample=$(basename "$dir" _output)
    bw_count=$(ls "${dir}/06_emapper/"*.bw 2>/dev/null | wc -l)
    echo "$sample: $bw_count BigWig files"
done
```

Expected: Each sample should have 3 BigWig files:
- `[SAMPLE]_final_F1R2.bw` (forward strand)
- `[SAMPLE]_final_F2R1.bw` (reverse strand)
- `[SAMPLE]_final_unstranded.bw` (combined)
