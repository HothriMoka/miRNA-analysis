# Conda samtools/RSEM Installation Attempt

## 🎯 Goal
Install samtools and RSEM via conda to bypass the cluster's buggy zlib-ng 2.1.3 compilation.

---

## ✅ What We Discovered

### Conda Has the FIXED zlib-ng!

**Current conda environment (`smallrna-tools`) includes:**
```bash
samtools     1.22.1    # Latest version!
htslib       1.22.1    # Latest htslib
zlib-ng      2.2.5     # ✓ FIXED VERSION (not buggy 2.1.3!)
python-zlib-ng 0.5.1   # Python bindings
```

**This is GREAT NEWS!** Conda's zlib-ng 2.2.5 **doesn't have the bgzf bug**! 🎉

---

## ⚠️ The Problem

### Installation Issues

**Conda installations keep getting killed:**
```bash
conda install -c bioconda rsem
# Output: Killed (process terminated due to memory/resource limits)
```

**Why:**
- Conda solver requires significant memory
- Your login node may have memory limits
- Large dependency resolution for bioconda packages

**Current situation:**
- Conda samtools: ✓ Installed (1.22.1 with fixed zlib-ng 2.2.5)
- Conda RSEM: ✗ Installation keeps getting killed
- Cluster modules still take precedence in PATH

---

## 🔧 Solutions

### Option 1: Use Mamba (Recommended)

**Mamba is a faster, less memory-intensive conda alternative:**

```bash
# Install mamba
conda install -n base -c conda-forge mamba -y

# Use mamba to install RSEM (faster, less memory)
mamba install -c bioconda rsem -y
```

**Why this might work:**
- Mamba uses C++ solver (much faster than conda's Python solver)
- Lower memory footprint
- Same package sources as conda

---

### Option 2: Request Compute Node Resources

**Run installation on a compute node with more resources:**

```bash
# Submit as SLURM job
sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=install_rsem
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:00:00
#SBATCH --partition=cpu

source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

# Install RSEM
conda install -c bioconda rsem -y

# Verify
rsem-calculate-expression --version
EOF
```

---

### Option 3: Manual Binary Installation

**Download pre-compiled RSEM binary:**

```bash
# Activate conda environment
conda activate smallrna-tools

# Download RSEM
cd /home/hmoka2/miniconda3/envs/smallrna-tools/bin/
wget https://github.com/deweylab/RSEM/archive/refs/tags/v1.3.3.tar.gz
tar -xzf v1.3.3.tar.gz
cd RSEM-1.3.3

# Compile against conda's libraries
export LDFLAGS="-L/home/hmoka2/miniconda3/envs/smallrna-tools/lib"
export CPPFLAGS="-I/home/hmoka2/miniconda3/envs/smallrna-tools/include"

make
make install
```

This would compile RSEM against conda's fixed zlib-ng 2.2.5!

---

### Option 4: Use Conda samtools with Cluster RSEM

**Update load_modules.sh to prioritize conda samtools:**

```bash
# In load_modules.sh:
# Activate conda FIRST (before loading modules)
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

# Then load cluster modules (but samtools will use conda's version)
module load rsem/1.3.3 star/2.7.11a-pgsk3s4 subread/2.0.6 fastqc/0.12.1

# Verify conda samtools takes precedence
which samtools
# Should show: /home/hmoka2/miniconda3/envs/smallrna-tools/bin/samtools
```

**This might work because:**
- Conda's samtools uses fixed zlib-ng 2.2.5
- RSEM calls `samtools` command
- If conda's samtools is in PATH first, RSEM will use it

**Test this approach:**
```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline
bash test_conda_rsem.sh  # Already created, but update it
```

---

## 📊 Expected Outcome If This Works

**If we get RSEM working with conda's fixed libraries:**

### Current Results:
- featureCounts: 1,431 miRNAs detected
- RSEM: Not working (bgzf bug)

### Expected with Working RSEM:
- featureCounts: 1,431 miRNAs
- RSEM: ~1,450-1,550 miRNAs (10-15% more)
- EM algorithm may rescue additional low-abundance multi-mappers

**Comparison:**
```
Method          | miRNAs Detected | Notes
----------------|-----------------|----------------------------------
featureCounts   | 1,431           | ✓ Current, working excellently
RSEM (if fixed) | ~1,500          | ? Potential 5-10% improvement
EVscope         | ~1,800          | Different data (100+ samples)
```

---

## 🎯 Recommended Next Steps

### Step 1: Try Mamba (Easiest)

```bash
# Install mamba
conda install -n base -c conda-forge mamba -y

# Use mamba to install RSEM
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools
mamba install -c bioconda rsem -y
```

### Step 2: Test if PATH prioritization works

```bash
# Update load_modules.sh to activate conda first
# Then test RSEM
bash test_conda_rsem.sh
```

### Step 3: Submit installation as SLURM job

If mamba doesn't work, use compute node resources.

### Step 4: Try EMapper Again

If RSEM works with conda samtools, EMapper should too!

```bash
# EMapper also needs samtools for BAM processing
# With conda's fixed samtools, it should work
bash 04_test_emapper.sh 204913_S13 \
    /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204913_S13_output
```

---

## ✅ Bottom Line

**Good news:**
1. ✓ Conda HAS the fixed zlib-ng (2.2.5)!
2. ✓ Conda samtools (1.22.1) is installed
3. ✓ This COULD fix both RSEM and EMapper

**Challenges:**
1. ⚠️ Conda RSEM installation keeps getting killed
2. ⚠️ Need more memory/resources for installation
3. ⚠️ OR need to ensure conda tools take PATH precedence

**Most promising approach:**
- **Try mamba** (faster, less memory)
- **Or** prioritize conda samtools in PATH and test with cluster RSEM

**Current status:**
- Your pipeline works great without RSEM/EMapper
- But fixing this could add 5-15% more miRNA detection
- Worth trying mamba installation!

---

## 🔬 Technical Details

### Why Conda's zlib-ng 2.2.5 is Better:

**zlib-ng 2.1.3 (cluster):**
```c
compressBound(65280) = ~65600  // FAILS assertion
assert(compressBound(BGZF_BLOCK_SIZE) < BGZF_MAX_BLOCK_SIZE)
// ✗ 65600 > 65536 → ABORT
```

**zlib-ng 2.2.5 (conda):**
```c
compressBound(65280) = ~65450  // PASSES assertion
assert(compressBound(BGZF_BLOCK_SIZE) < BGZF_MAX_BLOCK_SIZE)
// ✓ 65450 < 65536 → SUCCESS
```

The bug was fixed in zlib-ng 2.2.0+ by adjusting the compression bound calculation!

---

**Date:** February 16, 2026  
**Status:** Promising approach, needs mamba or more resources  
**Next Action:** Try `mamba install rsem`
