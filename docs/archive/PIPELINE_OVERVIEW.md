# Mouse Small RNA-seq Pipeline - Overview

## Pipeline Structure

```
mouse_smallRNA-pipeline/
├── 01_prepare_mouse_references.sh    # Build GRCm39 references (STAR, RSEM indices)
├── 02_smRNA_analysis.sh              # Single sample processing
├── 03_batch_process.sh               # Batch processing (sequential/parallel)
├── 04_rerun_rsem_all_samples.sh      # Re-run RSEM on all samples (fixes bgzf bug)
├── 05_run_emapper_all_samples.sh     # Generate BigWig coverage files
├── 06_visualize_coverage.sh          # Generate coverage density plots
├── RUN_FULL_PIPELINE.sh              # Master script - runs RSEM + EMapper
├── RUN_FULL_PIPELINE_WITH_VIZ.sh     # Master script - runs all steps including visualization
├── README.md                         # Main documentation
├── QUICKSTART.md                     # Quick start guide
├── SLURM_GUIDE.md                    # SLURM-specific instructions
├── Methodology_readme.md             # Detailed methodology
├── CHANGELOG.md                      # Version history
├── LICENSE                           # MIT License
├── load_modules.sh                   # Module loading utility
├── references/                       # Reference genomes and indices
│   ├── genome/                       # GRCm39 genome FASTA
│   ├── annotations/                  # GENCODE M38 GTF
│   ├── indices/                      # STAR and RSEM indices
│   └── bed_files/                    # BED files for RNA types (auto-generated)
├── scripts/                          # Python helper scripts
│   ├── Step_25_EMapper.py           # EM-based coverage estimation
│   ├── Step_25_bigWig2CPM.py        # BigWig to CPM conversion
│   ├── Step_15_featureCounts2TPM.py # featureCounts to TPM
│   ├── Step_17_RSEM2expr_matrix.py  # RSEM to expression matrix
│   ├── create_gene_metadata.py      # Gene metadata extraction
│   ├── create_rna_type_beds.py      # Create BED files for RNA types
│   └── plot_genetype_barplot.py     # Gene type visualization
├── logs/                             # SLURM and pipeline logs
├── tests/                            # Test scripts and validation
└── archive/                          # Troubleshooting docs (archived)
```

## Pipeline Workflow

### Step 1: Build References (One-time)
```bash
sbatch 01_prepare_mouse_references.sh
```
- Downloads GRCm39 genome and GENCODE M38 annotations
- Builds STAR and RSEM indices
- Creates gene metadata tables
- Resources: 16 CPUs, 120GB RAM, ~2 hours

### Step 2: Process Single Sample
```bash
sbatch 02_smRNA_analysis.sh SAMPLE_NAME input.fastq.gz --threads 16
```
- Adapter trimming (Takara SMARTer smRNA-Seq)
- Quality control (FastQC)
- Alignment (STAR, optimized for small RNAs)
- Quantification (featureCounts + RSEM)
- TPM calculation and miRNA extraction
- Gene type visualization
- Resources: 16 CPUs, 64GB RAM, ~1 hour per sample

### Step 3: Batch Processing (Optional)
```bash
sbatch 03_batch_process.sh /path/to/fastqs --threads 16
```
- Sequential processing of multiple samples
- For parallel processing, submit individual jobs instead

### Step 4: Re-run RSEM on All Samples
```bash
sbatch 04_rerun_rsem_all_samples.sh
```
- Re-runs RSEM quantification using conda's fixed version
- Fixes bgzf/samtools bug from previous runs
- Processes only samples missing RSEM results
- Generates TPM matrices and miRNA-specific results
- Resources: 16 CPUs, 64GB RAM, ~12-24 hours for 34 samples

### Step 5: Generate BigWig Coverage Files
```bash
sbatch 05_run_emapper_all_samples.sh
```
- Runs EMapper EM algorithm for coverage estimation
- Generates strand-specific BigWig files
- Handles multi-mapping reads properly
- Resources: 8 CPUs, 48GB RAM, ~6-12 hours for 34 samples

### Step 6: Visualize Coverage (Optional)
```bash
sbatch 06_visualize_coverage.sh
```
- Creates BED files for different RNA types from GTF
- Generates density plots showing coverage over RNA types (miRNA, tRNA, rRNA, etc.)
- Generates meta-gene profile plots
- Uses deepTools for publication-quality visualizations
- Resources: 4 CPUs, 16GB RAM, ~4-8 hours for 34 samples

### Run Complete Pipeline (RSEM + EMapper)
```bash
bash RUN_FULL_PIPELINE.sh
```
- Automatically runs steps 4 and 5 in sequence
- Sets up job dependencies (EMapper waits for RSEM)
- Total time: ~18-36 hours for all samples

### Run Complete Pipeline with Visualization
```bash
bash RUN_FULL_PIPELINE_WITH_VIZ.sh
```
- Automatically runs steps 4, 5, and 6 in sequence
- Sets up job dependencies (EMapper waits for RSEM, Viz waits for EMapper)
- Total time: ~22-44 hours for all samples

## Output Structure

For each sample `SAMPLE_NAME`:
```
/home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_miRNA/SAMPLE_NAME_output/
├── SAMPLE_NAME_ANALYSIS_SUMMARY.txt        # Summary report
├── 01_trimmed/
│   ├── SAMPLE_NAME_trimmed.fq.gz          # Trimmed reads
│   └── SAMPLE_NAME_cutadapt_report.txt    # Trimming stats
├── 02_aligned/
│   ├── SAMPLE_NAME_Aligned.sortedByCoord.out.bam       # Genomic alignment
│   ├── SAMPLE_NAME_Aligned.toTranscriptome.out.bam     # Transcriptome alignment (for RSEM)
│   └── SAMPLE_NAME_Log.final.out                       # STAR alignment stats
├── 03_counts/
│   ├── SAMPLE_NAME_featureCounts.tsv                   # Raw counts (featureCounts)
│   ├── SAMPLE_NAME_RSEM.genes.results                  # Gene quantification (RSEM)
│   └── SAMPLE_NAME_RSEM.isoforms.results               # Isoform quantification (RSEM)
├── 04_expression/
│   ├── SAMPLE_NAME_featureCounts_TPM.tsv               # All genes TPM (featureCounts)
│   ├── SAMPLE_NAME_RSEM_TPM.tsv                        # All genes TPM (RSEM)
│   ├── SAMPLE_NAME_miRNAs_only_featureCounts.tsv       # miRNA TPM (featureCounts)
│   ├── SAMPLE_NAME_miRNAs_only_RSEM.tsv                # miRNA TPM (RSEM) ⭐ USE THIS
│   └── SAMPLE_NAME_GeneType_Barplot.pdf                # Gene type distribution
├── 05_qc/
│   └── SAMPLE_NAME_trimmed_fastqc.html                 # Quality control report
├── 06_emapper/
│   ├── SAMPLE_NAME_final_F1R2.bw                       # Forward strand coverage
│   ├── SAMPLE_NAME_final_F2R1.bw                       # Reverse strand coverage
│   └── SAMPLE_NAME_final_unstranded.bw                 # Unstranded coverage
├── 07_coverage_plots/
│   ├── SAMPLE_NAME_final_unstranded_bed_density_heatmap.png      # Coverage density heatmap
│   ├── SAMPLE_NAME_final_unstranded_bed_stacked_profile_meta_gene.png  # Meta-gene profile
│   ├── density_plot.log                                # Density plot log
│   └── metagene_plot.log                               # Meta-gene plot log
└── logs/
    ├── SAMPLE_NAME_pipeline.log                        # Main pipeline log
    ├── rsem.log                                        # RSEM log
    └── *.log                                           # Step-specific logs
```

## Key Features

✅ **Latest References**: GRCm39 (GENCODE M38, Sept 2025)  
✅ **Correct Adapters**: Takara SMARTer smRNA-Seq protocol  
✅ **RSEM with EM**: Proper handling of multi-mapping reads  
✅ **Fixed bgzf Bug**: Uses conda's RSEM with zlib-ng 2.2.5  
✅ **EMapper Coverage**: EM-based single-base resolution coverage  
✅ **Coverage Visualization**: deepTools density plots and meta-gene profiles  
✅ **miRNA Focused**: Automatic extraction and quantification  
✅ **SLURM Optimized**: 16 CPUs max (cpu partition compliant)  
✅ **Comprehensive QC**: FastQC, alignment stats, gene type plots  

## Resource Requirements

| Step | CPUs | Memory | Time | Partition |
|------|------|--------|------|-----------|
| Reference building | 16 | 120GB | ~2h | cpu |
| Single sample | 16 | 64GB | ~1h | cpu |
| RSEM re-run (34 samples) | 8 | 48GB | 12-24h | cpu |
| EMapper (34 samples) | 8 | 48GB | 6-12h | cpu |
| Visualization (34 samples) | 4 | 16GB | 4-8h | cpu |

**Partition Limits**: `cpu` partition max = 16 CPUs, 250GB memory, 3 days

## Software Requirements

**Conda Environment** (`smallrna-tools`):
- Python 3.9+
- cutadapt 5.2
- RSEM 1.3.1 (with fixed zlib-ng 2.2.5)
- samtools 1.22.1
- pyBigWig, numba, pysam, psutil, numpy

**Cluster Modules**:
- STAR 2.7.11a
- subread/2.0.6 (featureCounts)
- FastQC 0.12.1

**Visualization Tools** (via conda):
- deepTools (computeMatrix, plotHeatmap, plotProfile)
- matplotlib, numpy (for color generation)

## Quick Start

```bash
# Navigate to pipeline directory
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Run complete pipeline on all samples (with visualization)
bash RUN_FULL_PIPELINE_WITH_VIZ.sh

# OR run without visualization
bash RUN_FULL_PIPELINE.sh

# Monitor jobs
squeue -u $USER
tail -f logs/rsem_rerun_all_*.log
tail -f logs/emapper_all_*.log
tail -f logs/coverage_viz_*.log
```

## Troubleshooting

### RSEM bgzf Error
**Symptom**: `samtools: bgzf.c:218: bgzf_hopen: Assertion failed`  
**Solution**: Script 04 uses conda's RSEM with fixed zlib-ng. Already fixed.

### EMapper Missing Dependencies
**Symptom**: `ModuleNotFoundError: No module named 'pyBigWig'`  
**Solution**: Activate conda environment: `conda activate smallrna-tools`

### No miRNAs Detected
**Symptom**: 0 miRNAs in output  
**Solution**: Check GTF has miRNA annotations:  
```bash
grep -c 'gene_type "miRNA"' references/annotations/gencode.vM38.annotation.gtf
# Should return >1000
```

## Documentation

- **README.md**: Detailed pipeline documentation
- **QUICKSTART.md**: Quick start guide with examples
- **SLURM_GUIDE.md**: SLURM-specific usage and best practices
- **Methodology_readme.md**: Scientific methodology and parameters
- **CHANGELOG.md**: Version history and updates

## Contact

For issues or questions, check the logs first:
```bash
less logs/SAMPLE_NAME_pipeline.log
less logs/rsem_rerun_all_*.log
less logs/emapper_all_*.log
```

## License

MIT License - See LICENSE file
