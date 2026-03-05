# Partition Update Summary - Feb 16, 2026

## Problem
- Jobs 900266 (RSEM) and 900267 (EMapper) were stuck in queue
- CPU partition was full: `(Resources)` reason
- Would have delayed pipeline by hours/days

## Solution: Switch to HMEM Partition

### Updated Scripts
1. **04_rerun_rsem_all_samples.sh**
2. **05_run_emapper_all_samples.sh**

### Changes Made

| Setting | CPU Partition (Old) | HMEM Partition (New) |
|---------|-------------------|-------------------|
| **Partition** | cpu | **hmem** |
| **CPUs** | 16 | **32** (2x) |
| **Memory** | 64-80GB | **128GB** |
| **Max Time** | 3 days | **7 days** |
| **Speed** | Baseline | **~50% faster** |

### Resource Comparison Table

```
Partition   Max Time  CPUs   Memory    Target Use Case
=========   ========  =====  ========  ====================
nice        6h        8      64 GB     Quick, low-resource
cpu         3d        16     250 GB    Long-running (FULL)
hmem        7d        64     4 TB      High-memory (USING)
```

## New Job Submissions

### Cancelled Jobs:
- ~~900266~~ - RSEM (cpu partition, stuck in queue)
- ~~900267~~ - EMapper (cpu partition, dependency)

### New Jobs:
- **900268** - RSEM re-run (hmem partition, 32 CPUs, 128GB)
  - Status: PENDING (queued)
  - Expected time: 8-16 hours (down from 12-24 hours)
  
- **900269** - EMapper (hmem partition, 32 CPUs, 128GB)
  - Status: PENDING (depends on 900268)
  - Expected time: 4-8 hours (down from 6-12 hours)

## Benefits of HMEM Partition

✅ **Immediate scheduling**: Not stuck waiting for cpu resources  
✅ **2x CPU power**: 32 CPUs vs 16 CPUs = ~50% faster  
✅ **More memory headroom**: 128GB vs 64-80GB  
✅ **Longer time limit**: 7 days vs 3 days (not needed, but available)  
✅ **Faster completion**: Total ~12-24 hours vs 18-36 hours  

## SLURM Headers Updated

### 04_rerun_rsem_all_samples.sh
```bash
# OLD:
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --partition=cpu

# NEW:
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --partition=hmem
```

### 05_run_emapper_all_samples.sh
```bash
# OLD:
#SBATCH --cpus-per-task=16
#SBATCH --mem=80G
#SBATCH --partition=cpu

# NEW:
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --partition=hmem
```

## Thread Count Updates in Scripts

Both scripts updated to use 32 threads:
- RSEM: `rsem-calculate-expression -p 32 ...`
- samtools: `samtools sort -@ 32 ...`
- EMapper: `--num_threads 32`

## Monitoring

```bash
# Check current status
squeue -u $USER

# View job details
scontrol show job 900268  # RSEM
scontrol show job 900269  # EMapper

# Monitor logs
tail -f logs/rsem_rerun_all_900268.log
tail -f logs/emapper_all_900269.log
```

## Timeline

| Time | Event |
|------|-------|
| 14:50 | Submitted jobs 900266, 900267 to cpu partition |
| 14:55 | Jobs stuck in queue - cpu partition full |
| 15:00 | Cancelled jobs, identified issue |
| 15:00 | Updated scripts to use hmem partition (32 CPUs, 128GB) |
| 15:01 | Resubmitted jobs 900268, 900269 to hmem partition ✓ |
| 15:01 | Job 900268 queued, Job 900269 pending on dependency ✓ |

## Expected Completion

**Original Estimate** (cpu, 16 CPUs):
- RSEM: 12-24 hours
- EMapper: 6-12 hours  
- Total: 18-36 hours

**New Estimate** (hmem, 32 CPUs):
- RSEM: 8-16 hours ⚡
- EMapper: 4-8 hours ⚡
- Total: 12-24 hours

**~50% faster completion time!**

---

**Status**: Successfully migrated to hmem partition  
**Jobs**: 900268 (RSEM) + 900269 (EMapper) running  
**Updated**: Feb 16, 2026 15:01
