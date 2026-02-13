# Mouse Small RNA-seq Pipeline Methodology

## **PURPOSE OF THE MOUSE_SMRNA_PIPELINE**

**Primary Goal:**
- Accurate detection and quantification of **miRNAs** and other small RNAs from mouse extracellular vesicle (EV) samples

**Specific Objectives:**
- Optimized for **Takara SMARTer smRNA-Seq Kit** (small RNA library preparation)
- Analyze **mouse genome** (GRCm39, GENCODE M38)
- Handle **multi-mapping reads** crucial for miRNA families (let-7, mir-17, etc.)
- Provide **rapid analysis** (~30-60 min per sample vs 4-6 hours for total RNA)
- Generate **TPM-normalized expression** matrices for downstream analysis
- Extract and rank miRNAs by abundance for biomarker discovery

---

## **METHODS ADAPTED FROM EVSCOPE-MIRNA PIPELINE**

**1. Core Quantification Approach:**
- **Dual quantification strategy**: featureCounts (fractional counting) + RSEM (EM algorithm)
- **Multi-mapping read handling**: Inherited EVscope's philosophy that multi-mappers are critical for miRNA families
- **TPM normalization**: Same Python scripts (`Step_15_featureCounts2TPM.py`, `Step_17_RSEM2expr_matrix.py`)

**2. Expression Matrix Generation:**
- Extracted EVscope's Python scripts for converting raw counts to expression matrices
- Metadata integration: GeneID → GeneSymbol → GeneType mapping
- RNA distribution analysis and visualization approach

**3. Quality Control Framework:**
- FastQC-based quality assessment (Steps 1-2 from EVscope)
- Comprehensive logging and summary report structure
- Alignment statistics reporting (STAR Log.final.out format)

**4. Computational Infrastructure:**
- Modular step-based architecture (EVscope has 27 steps; mouse pipeline has 9 steps)
- Bash-based workflow with error checking
- SLURM integration for HPC cluster execution

**5. Reference Annotation Philosophy:**
- Comprehensive RNA annotation including miRNAs, lncRNAs, protein-coding genes
- Use of GENCODE annotations (EVscope: v45 human; mouse pipeline: M38 mouse)
- GTF/GFF parsing for metadata extraction

**NOT Adapted (EVscope-specific features skipped):**
- ❌ UMI deduplication (SMARTer smRNA-Seq uses different protocol)
- ❌ CircRNA detection (CIRCexplorer2, CIRI2) - minimal in small RNA
- ❌ Two-pass STAR alignment - not needed for unspliced small RNAs
- ❌ Bacterial contamination screening (BBSplit, Kraken2) - simplified QC
- ❌ Tissue deconvolution - not primary goal
- ❌ Read-through adapter detection (custom UMI trimming)

---

## **METHODOLOGY OF MOUSE_SMRNA_PIPELINE**

### **A. Reference Preparation (Step 0)**

1. **Genome Download:**
   - GRCm39 primary assembly from GENCODE
   - GENCODE M38 comprehensive gene annotations (3,659,642 genes → 78,278 mouse genes)

2. **Index Building:**
   - **STAR index**: Optimized for small RNAs (`--sjdbOverhang 69` for 70bp reads)
   - **RSEM index**: Bowtie2-based for multi-mapping quantification
   - **Gene metadata**: Python script extracts GeneID/Symbol/Type from GTF

### **B. Single-Sample Analysis Pipeline (9 Steps)**

**Step 1: Adapter Trimming (cutadapt)**
- **Protocol-specific**: Takara SMARTer smRNA-Seq
  - `-u 3`: Remove 3bp TSO artifact from 5' end
  - `-a AAAAAAAAAA`: Trim polyA tail and 3' adapter
  - `-m 15`: Minimum read length 15bp
- **Quality filtering**: `--nextseq-trim 20`, `--max-n 0`
- **Output**: Trimmed FASTQ (~2.7M reads)

**Step 2: Quality Control (FastQC)**
- Post-trimming QC to verify adapter removal
- Read length distribution analysis
- HTML report generation

**Step 3: STAR Alignment (Small RNA-Optimized)**
- **Key parameters** (different from EVscope):
  - `--alignIntronMax 1`: No introns for small RNAs
  - `--alignEndsType EndToEnd`: Strict end-to-end alignment
  - `--outFilterMatchNmin 16`: Minimum 16bp match
  - `--outFilterMatchNminOverLread 0.9`: 90% of read must align
  - `--outFilterMismatchNmax 2`: Max 2 mismatches
  - `--outFilterMultimapNmax 100`: Allow multi-mapping (miRNA families)
- **Bug workaround**: Output unsorted BAM → samtools sort (STAR 2.7.11a bgzf issue)
- **Result**: ~48% unique mapping, ~17% multi-mapping

**Step 4: Quantification with featureCounts**
- **Mode**: Fractional counting (`-M --fraction`)
- **Features**: Count at exon level, summarize to gene
- **Strandedness**: Unstranded (`-s 0`) for total small RNA
- **Output**: Raw counts per gene (~490K reads assigned)

**Step 5: Quantification with RSEM (Optional)**
- **EM algorithm**: Probabilistically assign multi-mapping reads
- **Better for miRNA families**: let-7a/b/c share high similarity
- **Input**: Trimmed FASTQ (not BAM) for proper EM initialization
- **Fallback**: If fails (bgzf bug), pipeline continues with featureCounts

**Step 6: TPM Matrix Generation**
- Convert raw counts → TPM (Transcripts Per Million)
- Normalization accounts for gene length and library size
- Format: GeneID | GeneSymbol | GeneType | ReadCounts | TPM

**Step 7: miRNA Extraction**
- Filter for `GeneType == "miRNA"` from expression matrix
- Rank by TPM (highest to lowest)
- Top 10 display for quick QC
- Separate output files for miRNAs only

**Step 8: Summary Report Generation**
- Comprehensive text summary with:
  - Read statistics (input → trimmed → aligned)
  - Alignment metrics (unique/multi/unmapped)
  - Quantification results (genes detected, miRNAs found)
  - Top 5 miRNAs by abundance
- File paths for all outputs

**Step 9: Gene Type Barplot Visualization (NEW)**
- **Dual barplots**: Counts + Percentages
- **Top 15 gene types** by default
- High-resolution PDF (300 DPI)
- Distribution: lncRNA (41%), protein_coding (39%), miRNA (0.6%), etc.

### **C. Key Technical Specifications**

**Software Versions:**
- STAR: 2.7.11a-pgsk3s4
- RSEM: 1.3.3
- featureCounts (Subread): 2.0.6
- samtools: 1.17
- cutadapt: ≥4.0
- Python: 3.x with pandas, matplotlib

**Resource Requirements:**
- **Memory**: 80GB (STAR alignment), 120GB (index building)
- **CPUs**: 16 threads (max for cpu partition)
- **Time**: ~1-4 minutes per sample (analysis only)
- **Storage**: ~5-10GB per sample output

**SLURM Integration:**
- Batch job submission with resource management
- Automatic module loading (environment modules)
- Conda environment activation
- Parallel processing support (submit_batch_jobs.sh)

### **D. Output Structure**

**Expression Files:**
- `*_featureCounts_TPM.tsv`: All genes TPM matrix (47,997 genes)
- `*_miRNAs_only_featureCounts.tsv`: miRNA subset (286 detected)
- `*_GeneType_Barplot.pdf`: Gene type distribution visualization

**QC Files:**
- `*_trimmed_fastqc.html`: FastQC report
- `*_Log.final.out`: STAR alignment statistics
- `*_ANALYSIS_SUMMARY.txt`: Complete pipeline summary

**Raw Data:**
- `*_featureCounts.tsv`: Raw read counts
- `*_Aligned.sortedByCoord.out.bam`: Sorted BAM file
- `*_trimmed.fq.gz`: Trimmed reads

---

## **KEY DIFFERENCES: EVSCOPE VS MOUSE_SMRNA_PIPELINE**

| Feature | EVscope | mouse_smRNA_pipeline |
|---------|---------|----------------------|
| **Protocol** | SMARTer Total RNA-Seq | SMARTer smRNA-Seq |
| **Target** | All RNAs (mRNA, lncRNA, circRNA) | Small RNAs (miRNA, piRNA, snRNA) |
| **Genome** | Human (hg38, 3.6M features) | Mouse (GRCm39, 78K genes) |
| **Read type** | Paired-end 150bp | Single-end 70bp |
| **Adapter** | `-a AGATCGGAAGAGC` | `-u 3 -a AAAAAAAAAA` |
| **UMI** | 14bp in R2 + custom dedup | Not used |
| **STAR mode** | Two-pass (splice junctions) | Single-pass (no splicing) |
| **CircRNA** | Yes (CIRCexplorer2 + CIRI2) | No (minimal in small RNA) |
| **Steps** | 27 steps (~4-6 hours) | 9 steps (~30-60 min) |
| **Contamination** | BBSplit + Kraken2 | FastQC only |
| **Deconvolution** | GTEx + Brain Atlas | Not included |
| **Focus** | Comprehensive EV profiling | miRNA quantification |

---

## **DETAILED COMPARISON: STAR ALIGNMENT PARAMETERS**

### **EVscope STAR Command (Total RNA-seq)**
```bash
STAR --genomeDir "$STAR_INDEX" \
     --readFilesIn "$r1_dedup_fq" "$r2_dedup_fq" \
     --runThreadN "$thread_count" \
     --twopassMode Basic \              # Novel junction discovery
     --runMode alignReads \
     --quantMode GeneCounts \
     --readFilesCommand zcat \
     --outFilterMultimapNmax 100 \
     --winAnchorMultimapNmax 100 \
     --outSAMtype BAM SortedByCoordinate \
     --chimSegmentMin 10 \              # CircRNA detection
     --chimJunctionOverhangMin 10 \
     --chimScoreMin 1 \
     --chimOutType Junctions WithinBAM
```

### **mouse_smRNA_pipeline STAR Command (Small RNA-seq)**
```bash
STAR --genomeDir ${STAR_INDEX} \
     --readFilesIn ${TRIMMED_FQ} \
     --readFilesCommand zcat \
     --runThreadN ${THREADS} \
     --outSAMtype BAM Unsorted \        # Workaround for bgzf bug
     --outFilterMultimapNmax 100 \
     --winAnchorMultimapNmax 100 \
     --outFilterMismatchNmax 2 \        # Strict: max 2 mismatches
     --outFilterMatchNmin 16 \          # Min 16bp match for short reads
     --alignIntronMax 1 \               # No introns for small RNAs
     --alignEndsType EndToEnd \         # End-to-end alignment
     --outFilterMatchNminOverLread 0.9  # 90% of read must match
```

### **Parameter Rationale**

| Parameter | EVscope | mouse_smRNA_pipeline | Reason |
|-----------|---------|----------------------|--------|
| **Read type** | Paired-end | Single-end | EVscope: 150bp PE; SmRNA-seq: 70bp SE |
| **--twopassMode** | Basic | ❌ Not used | Small RNAs don't splice; no novel junctions |
| **--quantMode** | GeneCounts | ❌ Not used | Small RNA quant done separately (featureCounts/RSEM) |
| **Chimeric detection** | ✅ Enabled | ❌ Not used | CircRNAs not relevant for small RNA |
| **--alignIntronMax** | Default (1M) | **1** | Small RNAs have NO introns |
| **--alignEndsType** | Local (default) | **EndToEnd** | Short reads need end-to-end mapping |
| **--outFilterMismatchNmax** | Not set | **2** | Strict for short reads (16-30bp) |
| **--outFilterMatchNmin** | Not set | **16** | Min match length for specificity |
| **--outFilterMatchNminOverLread** | Not set (0.66) | **0.9** | 90% of read must align (stricter) |

---

## **EXAMPLE RESULTS: Sample 204925_S1**

**Input:**
- FASTQ: 4,780,175 reads (single-end, 70bp)

**After Trimming:**
- Reads: 2,708,972 (56.7% retained)
- Length: 15-70bp (mostly 18-40bp after adapter removal)

**STAR Alignment:**
- Uniquely mapped: 1,312,951 (48.47%)
- Multi-mapped: 451,975 (16.68%)
- Unmapped (too short): 542,135 (20.01%)

**Quantification:**
- Total genes detected: 47,997
- Genes with reads assigned: 489,843 reads
- miRNAs detected: 286 (with TPM > 0)

**Top 5 miRNAs:**
1. Gm55094: 34,698.90 TPM
2. Gm55936: 23,569.37 TPM
3. Gm56171: 14,715.28 TPM
4. Gm55276: 14,034.74 TPM
5. Mir6236: 12,949.76 TPM

**Gene Type Distribution:**
- lncRNA: 19,650 genes (40.94%)
- protein_coding: 18,796 genes (39.16%)
- processed_pseudogene: 4,275 genes (8.91%)
- TEC: 2,305 genes (4.80%)
- miRNA: 286 genes (0.60%)

---

## **CONCLUSION**

This pipeline represents a **specialized, streamlined adaptation** of EVscope's methodology, optimized specifically for small RNA-seq analysis with mouse samples. Key innovations include:

1. **Protocol-specific adapter trimming** for Takara SMARTer smRNA-Seq Kit
2. **Small RNA-optimized STAR alignment** with strict end-to-end mapping
3. **Rapid processing** (~4 minutes per sample vs. hours for total RNA)
4. **Robust multi-mapping handling** via fractional counting and EM algorithm
5. **Automated visualization** with gene type distribution barplots
6. **SLURM cluster integration** for high-throughput analysis

The pipeline successfully balances computational efficiency with analytical rigor, making it suitable for large-scale miRNA biomarker discovery studies in mouse EV samples.

---

## **CITATIONS**

**Original Pipeline:**
- **EVscope**: Zhao, Y., et al. (2025). EVscope: A Comprehensive Pipeline for Extracellular Vesicle RNA-Seq Analysis. DOI: 10.5281/zenodo.15577789

**Key Tools:**
- **STAR**: Dobin et al., Bioinformatics 2013
- **RSEM**: Li and Dewey, BMC Bioinformatics 2011
- **featureCounts**: Liao et al., Bioinformatics 2014
- **GENCODE**: Frankish et al., Nucleic Acids Res. 2021

**Protocol:**
- **Takara SMARTer smRNA-Seq Kit**: User Manual v2.0

---

**Document Version**: 1.0  
**Last Updated**: February 13, 2026  
**Pipeline Version**: mouse_smRNA_pipeline v1.0 (based on EVscope v2.4.0)
