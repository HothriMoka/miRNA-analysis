# Pipeline Status - February 16, 2026

## Repository Cleanup ✅ COMPLETE

### Actions Taken:
1. **Moved to `archive/`** (troubleshooting documents):
   - CONDA_SAMTOOLS_ATTEMPT.md
   - EMAPPER_GUIDE.md
   - EMAPPER_SUMMARY.md
   - PUSH_TO_GITHUB.md
   - RSEM_EMAPPER_INTEGRATION.md
   - RSEM_FIX_SUCCESS.md
   - SAMTOOLS_BGZF_ISSUE.md

2. **Moved to `tests/`** (test scripts and validation):
   - test_*.sh (all test scripts)
   - monitor_test.sh
   - install_conda_rsem.sh
   - test_rsem_conda/
   - test_rsem_conda_fixed/
   - test_rsem_transcriptome/
   - 04_test_emapper.sh

3. **Deleted**:
   - QUICK_PUSH.sh (unnecessary utility)

4. **Script Renaming** (correct pipeline order):
   - ~~06_rerun_rsem_all_samples.sh~~ → **04_rerun_rsem_all_samples.sh**
   - ~~05_run_emapper_all_samples.sh~~ → **05_run_emapper_all_samples.sh**

5. **Created**:
   - RUN_FULL_PIPELINE.sh (master script)
   - PIPELINE_OVERVIEW.md (comprehensive documentation)
   - PIPELINE_STATUS.md (this file)

## Final Pipeline Structure ✅

```
01_prepare_mouse_references.sh    # Build references (GRCm39, STAR, RSEM)
02_smRNA_analysis.sh              # Single sample analysis
03_batch_process.sh               # Batch processing
04_rerun_rsem_all_samples.sh      # Fix RSEM on all 34 samples
05_run_emapper_all_samples.sh     # Generate BigWig coverage files
RUN_FULL_PIPELINE.sh              # Master script
```

## SLURM Header Updates ✅ COMPLETE

All scripts updated to use **16 CPUs max** (cpu partition limit):
- ✅ 01_prepare_mouse_references.sh: 8 → 16 CPUs
- ✅ 02_smRNA_analysis.sh: 8 → 16 CPUs
- ✅ 03_batch_process.sh: Already 16 CPUs
- ✅ Documentation updated (QUICKSTART.md, SLURM_GUIDE.md)

## Current Pipeline Run Status 🚀 RUNNING

### Jobs Submitted (Updated to HMEM Partition):
- **Job 900268**: RSEM re-run (all 34 samples)
  - Status: PENDING (queued on hmem)
  - Partition: **hmem** (high-memory)
  - Resources: **32 CPUs, 128GB RAM**
  - Estimated time: 8-16 hours (faster with 32 CPUs)
  - Log: `logs/rsem_rerun_all_900268.log`
  
- **Job 900269**: EMapper (all 34 samples)
  - Status: PENDING (depends on RSEM completion)
  - Partition: **hmem** (high-memory)
  - Resources: **32 CPUs, 128GB RAM**
  - Estimated time: 4-8 hours (faster with 32 CPUs)
  - Log: `logs/emapper_all_900269.log`

### Why HMEM Partition?
- **Previous issue**: CPU partition was full (Jobs 900266, 900267 stuck in queue)
- **Solution**: Switched to hmem partition with more resources:
  - CPUs: 16 → 32 (2x faster processing)
  - Memory: 64-80GB → 128GB (plenty of headroom)
  - Max time: 3 days → 7 days (hmem has longer limit)
  - Expected completion: ~50% faster than original estimate

### Monitoring Commands:
```bash
# Check job status
squeue -u $USER

# Monitor RSEM progress
tail -f logs/rsem_rerun_all_900268.log

# Monitor EMapper progress (starts after RSEM)
tail -f logs/emapper_all_900269.log

# Check individual sample logs
tail -f /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/logs/rsem_rerun.log

# Check job details
scontrol show job 900268
scontrol show job 900269
```

## Problem Identified and Fixed 🔧

### Issue:
- 34 out of 35 samples failed RSEM quantification on Feb 13, 2026
- Error: `samtools: bgzf.c:218: bgzf_hopen: Assertion 'compressBound(BGZF_BLOCK_SIZE) < BGZF_MAX_BLOCK_SIZE' failed`
- Cause: Incompatible zlib version with cluster's samtools

### Solution:
- Updated `02_smRNA_analysis.sh` to use conda's RSEM (with fixed zlib-ng 2.2.5)
- Created `04_rerun_rsem_all_samples.sh` to re-process all affected samples
- Successfully tested on sample 204913_S13 (completed Feb 16, 2026)

## Expected Outputs

After pipeline completion, each sample will have:

### RSEM Results:
```
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/*/
├── 03_counts/
│   ├── *_RSEM.genes.results          # Gene quantification
│   └── *_RSEM.isoforms.results       # Isoform quantification
├── 04_expression/
│   ├── *_RSEM_TPM.tsv               # All genes TPM
│   └── *_miRNAs_only_RSEM.tsv       # miRNA-specific results ⭐
```

### EMapper BigWig Files:
```
├── 06_emapper/
│   ├── *_final_F1R2.bw              # Forward strand
│   ├── *_final_F2R1.bw              # Reverse strand
│   └── *_final_unstranded.bw        # Combined coverage
```

## Samples Being Processed

**Total**: 35 samples
- **Complete** (already has RSEM): 1 sample (204913_S13)
- **Re-running** (missing RSEM): 34 samples

Sample list:
```
204914_S9,  204915_S11, 204916_S15, 204918_S19, 204920_S33, 204921_S31,
204922_S27, 204923_S14, 204924_S16, 204925_S18, 207345_S22, 207346_S1,
207347_S8,  207348_S29, 207349_S25, 207351_S6,  207352_S5,  207356_S32,
209111_S2,  209113_S3,  209114_S10, 209120_S20, 223142_S17, 223143_S7,
223145_S21, 223146_S24, 223147_S30, 223148_S12, 223149_S26, 223151_S4,
223152_S23, 223153_S28, 249284_S34, 250496_S35
```

## Verification Steps

Once jobs complete, verify outputs:

```bash
# Check RSEM completion
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA

for dir in *_output; do
  sample=$(basename "$dir" _output)
  if [ -f "${dir}/03_counts/${sample}_RSEM.genes.results" ]; then
    genes=$(awk '$6>0' "${dir}/03_counts/${sample}_RSEM.genes.results" | tail -n +2 | wc -l)
    mirnas=$(awk -F'\t' 'NR>1 && $3~/miRNA/ && $5>0' "${dir}/04_expression/${sample}_RSEM_TPM.tsv" | wc -l)
    echo "✓ $sample - Genes: $genes, miRNAs: $mirnas"
  else
    echo "✗ $sample - RSEM missing"
  fi
done

# Check BigWig completion
for dir in *_output; do
  sample=$(basename "$dir" _output)
  bw_count=$(ls "${dir}/06_emapper/"*.bw 2>/dev/null | wc -l)
  if [ $bw_count -gt 0 ]; then
    echo "✓ $sample - $bw_count BigWig files"
  else
    echo "✗ $sample - No BigWig files"
  fi
done
```

## Next Steps (After Completion)

1. **Verify all outputs** using commands above
2. **Merge results** across samples for differential expression
3. **Create summary plots** (PCA, heatmaps, volcano plots)
4. **Downstream analysis**:
   - miRNA target prediction
   - Pathway enrichment
   - Differential expression (DESeq2/edgeR)

## Documentation

- **PIPELINE_OVERVIEW.md**: Complete pipeline documentation
- **README.md**: Main project documentation
- **QUICKSTART.md**: Quick start guide
- **SLURM_GUIDE.md**: SLURM-specific instructions
- **Methodology_readme.md**: Scientific methodology

## Timeline

| Date | Event |
|------|-------|
| Feb 13, 2026 | Initial pipeline run (34 samples failed RSEM) |
| Feb 16, 2026 10:00 | Identified bgzf bug issue |
| Feb 16, 2026 12:00 | Fixed 02_smRNA_analysis.sh with conda RSEM |
| Feb 16, 2026 14:00 | Tested fix on sample 204913_S13 ✓ |
| Feb 16, 2026 14:23 | Updated SLURM headers to 16 CPUs |
| Feb 16, 2026 14:44 | Cleaned up repository structure |
| Feb 16, 2026 14:50 | Submitted RSEM re-run (Job 900266, cpu partition) |
| Feb 16, 2026 14:50 | Submitted EMapper (Job 900267, cpu partition) |
| Feb 16, 2026 14:55 | CPU partition full - jobs stuck in queue |
| Feb 16, 2026 15:00 | Cancelled jobs 900266, 900267 |
| Feb 16, 2026 15:00 | Updated scripts to use hmem partition (32 CPUs, 128GB) |
| Feb 16, 2026 15:01 | Resubmitted: RSEM (Job 900268), EMapper (Job 900269) |
| Feb 17, 2026 | Expected completion ⏳ |

---

**Status**: Pipeline running on hmem partition  
**Last Updated**: Feb 16, 2026 15:01  
**Next Check**: Monitor job logs and verify completion
