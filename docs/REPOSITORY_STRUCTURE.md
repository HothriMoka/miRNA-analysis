# Repository Structure Guide

## Clean, Organized Pipeline Repository

## Root Directory (What You See First)

```
mouse_smallRNA-pipeline/
├── README.md ⭐                       # START HERE - Complete user guide
├── CHANGELOG.md                       # Version history
├── LICENSE                            # MIT license
│
├── Run_SmallRNA_Pipeline.sh ⭐        # Master script - edit configuration here
│
├── 01_prepare_mouse_references.sh    # Build genome references
├── 02_smRNA_analysis.sh              # Process single sample
├── 03_batch_process.sh               # Batch processing
├── 04_rerun_rsem_all_samples.sh      # RSEM quantification (batch)
├── 05_run_emapper_all_samples.sh     # Generate BigWig coverage (batch)
├── 06_visualize_coverage.sh          # Coverage plots (batch)
├── load_modules.sh                   # Load SLURM modules
│
├── scripts/                          # Python/shell helper scripts
├── references/                       # Genome data and indices
├── logs/                             # SLURM job logs
├── tests/                            # Test scripts
├── archive/                          # Archived old scripts
└── docs/                             # Documentation (organized)
```

## Documentation Structure (docs/)

```
docs/
├── INDEX.md ⭐                        # Documentation navigation guide
│
├── QUICKSTART.md                     # Quick reference commands
├── SLURM_GUIDE.md                   # Cluster usage guide
│
├── detailed/                         # 📘 Comprehensive user guides
│   ├── MASTER_SCRIPT_GUIDE.md       #    Complete script reference
│   ├── NEW_PLOTS_GUIDE.md           #    Expression plot interpretation
│   ├── VISUALIZATION_GUIDE.md       #    Coverage plot details
│   ├── LOG_FILES_GUIDE.md           #    Log locations & debugging
│   └── Methodology_readme.md        #    Scientific methodology
│
├── implementation/                   # 🔧 Technical documentation
│   ├── IMPLEMENTATION_SUMMARY_FEB17.md
│   ├── PIPELINE_CONSOLIDATION_SUMMARY.md
│   ├── STEP26_IMPLEMENTATION_SUMMARY.md
│   ├── CONFIGURATION_VERIFICATION.md
│   ├── PLOT_COMPARISON_EVSCOPE_VS_MOUSE.md
│   └── DOCUMENTATION_CLEANUP_SUMMARY.md
│
└── archive/                          # 📦 Historical documents
    ├── PARTITION_UPDATE_SUMMARY.md
    ├── PIPELINE_STATUS.md
    ├── VISUALIZATION_FIX_SUMMARY.md
    └── PIPELINE_OVERVIEW.md
```

## Scripts Directory

```
scripts/
├── Step_15_featureCounts2TPM.py          # Counts → TPM conversion
├── Step_17_RSEM2expr_matrix.py           # RSEM → expression matrix
├── Step_25_EMapper.py                    # EM-based coverage calculation
├── Step_25_bigWig2CPM.py                 # BigWig normalization
│
├── create_gene_metadata.py               # Extract gene info from GTF
├── create_rna_type_beds.py               # Create BED files for RNA types
│
├── plot_genetype_barplot.py              # Gene type distribution
├── plot_RNA_distribution_2subplots.py    # RNA composition analysis
├── plot_top_expressed_genes.py           # Top genes visualization
│
├── density_plot_over_RNA_types.sh        # Coverage density heatmap
└── metagene_plot.sh                      # Meta-gene profile plot
```

## References Directory

```
references/
├── genome/
│   └── GRCm39.genome.fa              # Mouse genome FASTA
├── annotations/
│   ├── gencode.vM38.annotation.gtf   # Gene annotations
│   └── mm39_geneID_Symbol_RNAtype.tsv # Gene metadata
├── indices/
│   ├── star/                         # STAR alignment index
│   └── RSEM/                         # RSEM quantification index
└── bed_files/                        # BED files for RNA types
    ├── mm39_miRNA.bed
    ├── mm39_tRNA.bed
    ├── mm39_rRNA.bed
    └── ... (other RNA types)
```

## What to Read When

### 🚀 Getting Started

1. **README.md** (root) - Quick start and basic usage
2. Edit **Run_SmallRNA_Pipeline.sh** - Set your paths
3. Run pipeline
4. Done!

### 📊 Understanding Results

**QC Plots:** `docs/detailed/NEW_PLOTS_GUIDE.md`
- How to interpret expression plots
- What good vs bad samples look like
- QC checklist

**Coverage Plots:** `docs/detailed/VISUALIZATION_GUIDE.md`
- Understanding heatmaps and profiles
- Troubleshooting visualization

### 🔧 Advanced Usage

**Master Script Details:** `docs/detailed/MASTER_SCRIPT_GUIDE.md`
- All configuration options
- Advanced workflows
- Custom resource allocation

**SLURM Commands:** `docs/SLURM_GUIDE.md`
- Job monitoring
- Queue management
- Cluster-specific tips

### 🐛 Troubleshooting

**First:** README.md (Troubleshooting section)

**If not solved:** `docs/detailed/LOG_FILES_GUIDE.md`
- Where to find logs
- How to interpret errors
- Common issues and solutions

### 👨‍💻 Development/Maintenance

**Implementation details:** `docs/implementation/`
- How scripts were built
- Technical decisions
- Comparison with EVscope

**Historical context:** `docs/archive/`
- Past issues and fixes
- Evolution of the pipeline
- Old run records

## File Counts by Directory

| Directory | Files | Purpose |
|-----------|-------|---------|
| **Root** | 3 .md files | Essential info only |
| **docs/** | 2 .md files | Quick reference |
| **docs/detailed/** | 5 .md files | Comprehensive guides |
| **docs/implementation/** | 6 .md files | Technical docs |
| **docs/archive/** | 4 .md files | Historical records |
| **scripts/** | 12 files | Analysis scripts |
| **references/** | Auto-generated | Genome data |

## Navigation Tips

### Quick Command Reference

```bash
# See all documentation
ls docs/

# Find specific topic
grep -r "adapter" docs/

# Read navigation guide
cat docs/INDEX.md
```

### Visual Tree

```bash
# Install tree if needed: sudo apt install tree

# View structure
tree -L 2 -I 'references|logs|tests'

# View docs only
tree docs/
```

## Benefits of This Structure

### ✅ User-Friendly
- Clear starting point (README.md)
- Not overwhelmed by many files
- Easy to find information

### ✅ Maintainable
- Logical organization
- Easy to add new docs
- Clear separation of concerns

### ✅ Professional
- Clean repository
- Standard structure
- Version control friendly

### ✅ Comprehensive
- Nothing lost
- Everything organized
- Easy to navigate

## Quick Links

**Essential:**
- `README.md` - Start here
- `Run_SmallRNA_Pipeline.sh` - Edit configuration

**Reference:**
- `docs/QUICKSTART.md` - Common commands
- `docs/INDEX.md` - Documentation guide

**Detailed:**
- `docs/detailed/` - Comprehensive guides
- `docs/implementation/` - Technical details

## Summary

**Before:** 18 markdown files scattered in root → Overwhelming  
**After:** 3 markdown files in root + organized docs/ → Clean and navigable  

**User journey is now:**
1. Open repository
2. See README.md (obviously the first file)
3. Follow quick start
4. Refer to docs/ only if needed

**Result:** Professional, easy-to-use repository structure! ✅

---

**Last Updated:** February 17, 2026  
**Status:** Production-ready, well-organized, user-friendly
