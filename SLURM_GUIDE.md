# SLURM Job Submission Guide

Complete guide for running the pipeline on a SLURM cluster.

---

## 📋 Quick Reference

### Submit Reference Preparation
```bash
sbatch 01_prepare_mouse_references.sh
```

### Submit Single Sample
```bash
sbatch 02_smRNA_analysis.sh SAMPLE_NAME input.fastq.gz --threads 16
```

### Submit All Samples (Parallel - RECOMMENDED)
```bash
./submit_batch_jobs.sh /path/to/fastqs --threads 16
```

---

## 🎯 Recommended Workflow

### Step 1: Prepare Environment
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/mouse_smRNA_pipeline

# Create logs directory
mkdir -p logs

# Load modules (do this in your submission scripts or .bashrc)
module load star/2.7.11a rsem/1.3.3 subread/2.0.6 fastqc/0.12.1 samtools
source $(conda info --base)/etc/profile.d/conda.sh
conda activate smallrna-tools
```

**Cluster Partition Limits:**
- `cpu` partition: 16 CPUs max, 250GB memory, 3 days max time
- All pipeline jobs use the `cpu` partition

### Step 2: Build References (First Time Only)
```bash
# Submit reference building job
sbatch 01_prepare_mouse_references.sh

# Check status
squeue -u $USER

# Or check logs
tail -f logs/prep_refs_*.log
```

**Resources:**
- Memory: 80GB
- CPUs: 16 (max for cpu partition)
- Time: ~1.5-2 hours
- Partition: cpu

### Step 3: Submit Sample Jobs

#### Option A: Automatic Batch Submission (EASIEST)
```bash
# Submit all samples as separate jobs
./submit_batch_jobs.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5 \
  --threads 16 \
  --mem 48G \
  --time 4:00:00

# With automatic dependency on reference job
./submit_batch_jobs.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5 \
  --dependency
```

This will:
- Submit one SLURM job per sample
- All jobs run in parallel
- Automatically use SLURM's `$SLURM_CPUS_PER_TASK` variable
- Create individual log files per sample

#### Option B: Manual Submission (More Control)
```bash
# Submit individual samples (uses SBATCH defaults: 16 CPUs, 48GB, 4h)
sbatch 02_smRNA_analysis.sh 204925 \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5/204925_S1_R1_001.fastq.gz

sbatch 02_smRNA_analysis.sh 207352 \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5/207352_S2_R1_001.fastq.gz

# ... etc for each sample
```

#### Option C: Loop Submission
```bash
cd /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5

for fq in *_R1_001.fastq.gz; do
  sample=$(basename $fq | sed 's/_R1_001.fastq.gz$//')
  sbatch /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/mouse_smRNA_pipeline/02_smRNA_analysis.sh \
    $sample $fq --threads 20
done
```

---

## 📊 Resource Requirements

### Reference Preparation (`01_prepare_mouse_references.sh`)
```
#SBATCH --cpus-per-task=16
#SBATCH --mem=80G
#SBATCH --time=4:00:00
#SBATCH --partition=cpu
```
- **Why 80GB**: STAR genome indexing needs ~60-70GB for mouse
- **Why 16 CPUs**: Max for cpu partition; speeds up STAR and RSEM indexing
- **Why 4 hours**: Download (30min) + STAR index (1.5h) + RSEM index (30min-1h)

### Sample Analysis (`02_smRNA_analysis.sh`)
```
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=4:00:00
#SBATCH --partition=cpu
```
- **Why 48GB**: STAR alignment needs ~40GB for mouse genome
- **Why 16 CPUs**: Max for cpu partition; STAR, RSEM, featureCounts benefit from multi-threading
- **Why 4 hours**: Safe buffer; typical samples complete in 30-60 minutes

### Batch Processing (`03_batch_process.sh`)
```
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=12:00:00
#SBATCH --partition=cpu
```
- **Why 12 hours**: For sequential processing of 6 samples (~2 hours each)
- **Not recommended**: Use `submit_batch_jobs.sh` instead for parallel submission

**Partition Limits:**
- `cpu` partition max: 16 CPUs, 250GB memory, 3 days
- All jobs fit comfortably within these limits

---

## 🔍 Monitoring Jobs

### Check Job Status
```bash
# All your jobs
squeue -u $USER

# Specific jobs
squeue -j 12345,12346,12347

# With more details
squeue -u $USER -o "%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R"
```

### View Logs in Real-Time
```bash
# Follow all logs
tail -f logs/*.log

# Follow specific sample
tail -f logs/204925_*.log

# Check errors
tail -f logs/*.err
```

### Job Statistics After Completion
```bash
# Detailed info
seff 12345

# Accounting info
sacct -j 12345 --format=JobID,JobName,Elapsed,CPUTime,MaxRSS,State
```

---

## 🛑 Managing Jobs

### Cancel Jobs
```bash
# Cancel specific job
scancel 12345

# Cancel all your jobs
scancel -u $USER

# Cancel specific job pattern
scancel --name=smRNA_analysis
```

### Hold/Release Jobs
```bash
# Hold job (prevent from starting)
scontrol hold 12345

# Release held job
scontrol release 12345
```

### Modify Running Job
```bash
# Extend time limit
scontrol update job=12345 TimeLimit=8:00:00
```

---

## 📁 SLURM Output Files

### Log Files
```
logs/
├── prep_refs_123456.log        # Reference building stdout
├── prep_refs_123456.err        # Reference building stderr
├── 204925_123457.log           # Sample 204925 stdout
├── 204925_123457.err           # Sample 204925 stderr
├── 207352_123458.log           # Sample 207352 stdout
└── ...
```

### Job ID Tracking
```
logs/
└── submitted_jobs_20260213_120000.txt  # List of submitted job IDs
```

---

## ⚡ Advanced SLURM Features

### Array Jobs (Alternative to submit_batch_jobs.sh)

Create a sample list:
```bash
# Create samples.txt
ls /path/to/fastqs/*_R1_001.fastq.gz > samples.txt
```

Submit as array:
```bash
sbatch --array=1-6 02_smRNA_analysis.sh
```

Then modify `02_smRNA_analysis.sh` to read from line `$SLURM_ARRAY_TASK_ID` of `samples.txt`.

### Job Dependencies

```bash
# Submit reference job
REF_JOB=$(sbatch --parsable 01_prepare_mouse_references.sh)

# Submit sample jobs that wait for reference job
sbatch --dependency=afterok:$REF_JOB 02_smRNA_analysis.sh sample1 input1.fq.gz
sbatch --dependency=afterok:$REF_JOB 02_smRNA_analysis.sh sample2 input2.fq.gz
```

### Email Notifications

Add to SBATCH headers:
```bash
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=your.email@example.com
```

Or specify at submission:
```bash
sbatch --mail-type=END --mail-user=you@example.com 02_smRNA_analysis.sh ...
```

---

## 🐛 Troubleshooting SLURM Issues

### Job Pending with Reason

```bash
squeue -u $USER -o "%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R"
```

Common reasons:
- `Resources`: Waiting for requested resources
- `Priority`: Lower priority than other jobs
- `Dependency`: Waiting for another job to complete
- `QOSMaxCpuPerUserLimit`: You've hit CPU limit

### Job Failed Immediately

Check error log:
```bash
cat logs/sample_123456.err
```

Common issues:
- Module not loaded
- Conda environment not activated
- Input file not found
- Insufficient memory

**Solution**: All scripts now auto-detect SLURM environment and load resources appropriately.

### Out of Memory

Your job was killed (state: `OUT_OF_MEMORY` or `OOM`):

```bash
# Check memory usage
sacct -j 123456 --format=JobID,MaxRSS,ReqMem,State
```

**Solution**: Increase memory in SBATCH header or at submission:
```bash
sbatch --mem=64G 02_smRNA_analysis.sh ...
```

### Job Timeout

Job exceeded time limit:

**Solution**: Increase time:
```bash
sbatch --time=8:00:00 02_smRNA_analysis.sh ...
```

---

## 📝 SLURM Partition Information

Check available partitions:
```bash
sinfo

# Or
scontrol show partition
```

Select partition at submission:
```bash
sbatch --partition=highmem 01_prepare_mouse_references.sh
sbatch --partition=gpu 02_smRNA_analysis.sh sample1 input1.fq.gz  # (not needed, just example)
```

---

## ✅ Verification Checklist

Before submitting:
- [ ] Modules loaded (star, rsem, subread, fastqc, samtools)
- [ ] Conda environment activated (smallrna-tools)
- [ ] Logs directory exists: `mkdir -p logs`
- [ ] Input FASTQ files exist and are readable
- [ ] Sufficient disk space (check with `df -h`)

After submission:
- [ ] Jobs appear in queue: `squeue -u $USER`
- [ ] Log files being created: `ls -lh logs/`
- [ ] No immediate errors: `cat logs/*.err`

---

## 📞 Getting Help

### SLURM Documentation
```bash
man sbatch
man squeue
man scancel
```

### Cluster-Specific Help
Contact your HPC support team for:
- Available partitions and QOS
- Resource limits
- Queue policies
- Priority calculations

---

## 🎯 Summary: Best Practice Workflow

```bash
# 1. One-time setup
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/EVscope-mirna/mouse_smRNA_pipeline
mkdir -p logs

# 2. Submit reference building
sbatch 01_prepare_mouse_references.sh

# 3. Wait for completion (check with squeue)
squeue -u $USER

# 4. Submit all samples in parallel
./submit_batch_jobs.sh \
  /home/hmoka2/mnt/network/dataexchange/scott/genomics/nextseq2000/251017_VH00409_43_AAH7FHVM5

# 5. Monitor
tail -f logs/*.log

# 6. Check results
ls -lh *_output/
cat *_output/*_ANALYSIS_SUMMARY.txt
```

**Total time: ~2.5 hours** (1.5-2h for references with 16 CPUs, 30-60min for all samples in parallel)

**Partition Used:** `cpu` (16 CPUs max, 250GB memory, 3 days time limit)

---

**Questions?** Check logs first: `less logs/*.log`
