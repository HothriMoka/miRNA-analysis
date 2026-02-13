# Changelog

## v1.0 - February 2026

### Initial Release

**Pipeline Features:**
- Mouse genome (GRCm39/GENCODE M38) support
- Takara SMARTer smRNA-Seq adapter handling
- SLURM cluster optimization
- Comprehensive QC and reporting
- miRNA-specific extraction and quantification
- Gene type distribution visualization

**Core Components:**
- `01_prepare_mouse_references.sh` - Reference genome setup
- `02_smRNA_analysis.sh` - Single-sample analysis pipeline
- `03_batch_process.sh` - Batch processing wrapper
- `load_modules.sh` - Environment setup
- 4 Python helper scripts for TPM conversion and plotting

**Documentation:**
- `README.md` - Comprehensive usage guide
- `QUICKSTART.md` - Quick start instructions
- `SLURM_GUIDE.md` - Cluster usage guide
- `Methodology_readme.md` - Detailed methodology

**Key Capabilities:**
- Detects 10-20% of 2,201 annotated miRNAs per sample
- Processes samples in 1-2 minutes with 16 CPUs
- Gracefully handles RSEM failures (bgzf bug)
- Generates publication-ready visualizations

**Adapted From:**
- EVscope pipeline (total RNA-seq for EVs)
- Modified for small RNA-seq specific requirements
