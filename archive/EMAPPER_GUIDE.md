# EMapper Integration Guide

## Overview

EMapper uses **Expectation-Maximization (EM)** algorithm to probabilistically assign multi-mapping reads and generate genome-wide coverage tracks (BigWig files) with CPM normalization.

### Why Add EMapper to Your Pipeline?

| Method | Approach | Multi-mapping Handling | miRNA Detection |
|--------|----------|----------------------|-----------------|
| **featureCounts** | Direct counting | Fractional (`--fraction`) | Conservative |
| **RSEM** | EM algorithm | Probabilistic | Moderate (if working) |
| **EMapper** | EM algorithm + Coverage | Probabilistic + BigWig | **Potentially Higher** |

**Key Advantages:**
- ✅ **EM algorithm** rescues multi-mapping reads (important for miRNA families)
- ✅ **Generates BigWig files** for visualization in genome browsers
- ✅ **CPM normalization** for expression quantification
- ✅ **Strand-specific** coverage tracking
- ✅ **Works reliably** (no bgzf bug like RSEM)

---

## Installation ✓ COMPLETED

Dependencies have been installed in your `smallrna-tools` conda environment:
- ✅ pyBigWig 0.3.25
- ✅ numba 0.60.0
- ✅ pysam 0.23.3
- ✅ psutil 7.2.2

**Scripts added to your pipeline:**
- `scripts/Step_25_EMapper.py` - EM-based coverage generator
- `scripts/Step_25_bigWig2CPM.py` - BigWig to CPM converter
- `04_test_emapper.sh` - Test script

---

## Quick Test

Test EMapper on one of your existing samples:

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Example: Test on an existing sample from mouse_miRNA directory
sbatch 04_test_emapper.sh 204913_S13 \
    /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/204913_S13_output
```

**What it does:**
1. Runs EMapper on your existing BAM file
2. Generates BigWig files (coverage tracks)
3. Extracts miRNA-only quantification
4. Compares results with featureCounts
5. Shows top 10 miRNAs from each method

**Expected runtime:** 5-10 minutes per sample

---

## EMapper Workflow

```
Input: Sorted BAM file
    ↓
[EMapper.py]
├─ Parse alignments (unique + multi-mapping)
├─ Initial coverage estimation
├─ EM iterations (default: 10)
│   └─ Probabilistically redistribute multi-mappers
├─ Generate strand-specific BigWig files:
│   ├─ *_unique_F1R2.bw (forward, unique)
│   ├─ *_unique_F2R1.bw (reverse, unique)
│   ├─ *_multi_F1R2.bw (forward, multi)
│   ├─ *_multi_F2R1.bw (reverse, multi)
│   ├─ *_final_F1R2.bw (forward, combined)
│   ├─ *_final_F2R1.bw (reverse, combined)
│   └─ *_final_unstranded.bw (both strands)
    ↓
[bigWig2CPM.py]
├─ Extract coverage for miRNA genes
├─ Calculate mean per-base CPM
└─ Output: miRNA_CPM.tsv
    ↓
[Compare with featureCounts]
└─ Identify differences in detection
```

---

## Expected Results

### What to Expect from Test:

**Scenario 1: Similar Detection** (most common)
```
featureCounts detected: 248 miRNAs
EMapper detected:       250 miRNAs
```
- EMapper may detect 0-10% more miRNAs
- Mainly from better multi-mapping handling

**Scenario 2: Significantly More Detection** (if lucky!)
```
featureCounts detected: 248 miRNAs
EMapper detected:       285 miRNAs
```
- EMapper's EM algorithm rescues ~15% more miRNAs
- Especially for miRNA families with high homology

**Scenario 3: Similar but Different Quantification**
- Same miRNAs detected
- But expression levels differ slightly
- EMapper redistributes multi-mappers differently

---

## Interpreting Results

### Good Signs:
- ✅ EMapper detects ≥ featureCounts miRNAs
- ✅ Top 10 miRNAs are similar between methods
- ✅ Both methods agree on highly expressed miRNAs

### What Differences Mean:
- **More miRNAs in EMapper:** EM rescued low-abundance multi-mappers
- **Slightly different CPM/TPM:** Different normalization strategies
- **Different top rankings:** EM redistributed reads to homologous miRNAs

---

## Full Integration (Optional)

If you want to add EMapper as a standard pipeline step:

### Option 1: Add to 02_smRNA_analysis.sh

Insert after STAR alignment:

```bash
# === Step 4.5: EMapper Coverage Analysis ===
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Step 4.5: EMapper Coverage Analysis ==="

EMAPPER_DIR="${OUTPUT_DIR}/06_emapper"
mkdir -p "${EMAPPER_DIR}"

python "${SCRIPTS_DIR}/Step_25_EMapper.py" \
    --input_bam "${SORTED_BAM}" \
    --gtf "${GTF_FILE}" \
    --output_dir "${EMAPPER_DIR}" \
    --prefix "${SAMPLE_NAME}" \
    --num_workers 16 \
    --split_by_strand yes \
    --unique_only no \
    --em_iterations 10

# Extract miRNA CPM
MIRNA_GTF="${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_only.gtf"
grep -w "gene" "${GTF_FILE}" | grep 'gene_type "miRNA"' > "${MIRNA_GTF}"

python "${SCRIPTS_DIR}/Step_25_bigWig2CPM.py" \
    --stranded no \
    --input_F1R2_bw "${EMAPPER_DIR}/${SAMPLE_NAME}_final_F1R2.bw" \
    --input_F2R1_bw "${EMAPPER_DIR}/${SAMPLE_NAME}_final_F2R1.bw" \
    --gtf "${MIRNA_GTF}" \
    --output "${EMAPPER_DIR}/${SAMPLE_NAME}_miRNA_CPM.tsv"

echo "✓ EMapper analysis complete"
```

### Option 2: Standalone Script (Recommended for Now)

Keep using `04_test_emapper.sh` on specific samples of interest.

---

## BigWig File Usage

### Visualize in IGV (Integrative Genomics Viewer)

1. **Load mouse genome (mm39)**
2. **Load BigWig files:**
   - `*_final_unstranded.bw` - Combined coverage
   - `*_final_F1R2.bw` - Forward strand
   - `*_final_F2R1.bw` - Reverse strand

3. **Navigate to miRNA genes:**
   - Search for gene (e.g., "Mir125b-2")
   - Visualize coverage profile
   - Confirm expression levels

### Use Cases:
- **QC:** Check coverage uniformity across miRNAs
- **Discovery:** Identify unannotated small RNAs
- **Validation:** Confirm specific miRNA expression visually
- **Publication:** Generate coverage tracks for figures

---

## Troubleshooting

### Issue 1: Memory Error

**Error:** `MemoryError` during EMapper

**Solution:** Reduce `--num_workers`:
```bash
--num_workers 8  # Instead of 16
```

### Issue 2: No Multi-mapping Reads

**Warning:** `No multi-mapping reads found`

**Explanation:** Normal if your alignment stringency is high. EMapper will still work with unique reads only.

### Issue 3: EMapper Detects Fewer miRNAs

**Unlikely but possible:** featureCounts is very good for small RNA-seq

**Action:** Use featureCounts results (already excellent for your data)

---

## Performance Expectations

| Step | Time | Memory | Output Size |
|------|------|--------|-------------|
| EMapper (10 iterations) | 5-8 min | ~40-60 GB | BigWig: ~200-500 MB |
| BigWig2CPM | 1-2 min | ~4 GB | TSV: ~50 KB |
| **Total** | **6-10 min** | **60 GB** | **~500 MB/sample** |

---

## Decision Guide: Should You Use EMapper?

### Use EMapper If:
- ✅ You want to **visualize coverage** in genome browsers
- ✅ You're interested in **multi-mapping miRNAs** (families)
- ✅ You want an **alternative quantification** method
- ✅ You're exploring **unannotated small RNAs**
- ✅ You need **BigWig files** for downstream analysis

### Stick with featureCounts If:
- ✅ Your current results are satisfactory (165-437 miRNAs detected)
- ✅ You want **faster processing** (~1-2 min vs 6-10 min)
- ✅ Storage is limited (no BigWig files needed)
- ✅ Standard count-based quantification is sufficient

---

## Next Steps

1. **Test on one sample:**
   ```bash
   sbatch 04_test_emapper.sh SAMPLE_NAME SAMPLE_OUTPUT_DIR
   ```

2. **Review comparison:**
   - Check log file for comparison results
   - Look at `miRNA_CPM.tsv` output
   - Compare top 10 miRNAs with featureCounts

3. **Decide:**
   - If EMapper detects significantly more miRNAs → integrate into pipeline
   - If results are similar → use featureCounts (faster, simpler)
   - If you want BigWig files → add EMapper regardless

4. **Optional: Batch run on all samples** (if integrating):
   ```bash
   for dir in /path/to/mouse_miRNA/*_output; do
       sample=$(basename "$dir" _output)
       sbatch 04_test_emapper.sh "$sample" "$dir"
   done
   ```

---

## Key Differences from EVscope

| Feature | EVscope | Your Pipeline |
|---------|---------|---------------|
| **Purpose** | Total RNA-seq coverage | Small RNA miRNA detection |
| **BigWig use** | Essential (splicing, isoforms) | Optional (visualization) |
| **EM importance** | Moderate (many RNA types) | High (miRNA families) |
| **Primary method** | featureCounts + RSEM + EMapper | featureCounts (+ EMapper optional) |

---

## Support

For issues or questions:
1. Check test output logs
2. Review EMapper Python script help: `python scripts/Step_25_EMapper.py --help`
3. Compare outputs with featureCounts results

---

## Citation

If you use EMapper results, cite:
- **EMapper:** Custom EM-based coverage tool from EVscope pipeline
- **EVscope:** [Original EVscope publication]

---

**Ready to test?** Run the test script and see if EMapper helps detect more miRNAs in your data! 🚀
