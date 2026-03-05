# Documentation Index

## Quick Access

**Start here:** `../README.md` - Main documentation with quick start guide

## Reference Guides

- **QUICKSTART.md** - Quick start examples and common commands
- **SLURM_GUIDE.md** - SLURM-specific usage and cluster information

## Detailed Guides (detailed/)

- **MASTER_SCRIPT_GUIDE.md** - Complete master script reference and advanced usage
- **NEW_PLOTS_GUIDE.md** - Expression plot interpretation and QC guidelines
- **VISUALIZATION_GUIDE.md** - Coverage visualization details
- **LOG_FILES_GUIDE.md** - Log file locations and troubleshooting
- **Methodology_readme.md** - Scientific methodology and parameters

## Implementation Details (implementation/)

- **IMPLEMENTATION_SUMMARY_FEB17.md** - Expression plots implementation record
- **PIPELINE_CONSOLIDATION_SUMMARY.md** - Master script consolidation details
- **STEP26_IMPLEMENTATION_SUMMARY.md** - Coverage visualization implementation
- **CONFIGURATION_VERIFICATION.md** - Configuration system verification
- **PLOT_COMPARISON_EVSCOPE_VS_MOUSE.md** - EVscope vs mouse pipeline comparison

## Archive (archive/)

Historical documents and status files:

- **PARTITION_UPDATE_SUMMARY.md** - SLURM partition change history
- **PIPELINE_STATUS.md** - Pipeline run status (historical)
- **VISUALIZATION_FIX_SUMMARY.md** - Coverage plot fixes
- **PIPELINE_OVERVIEW.md** - Original pipeline overview (superseded by README)

## Document Organization

```
docs/
├── INDEX.md (this file)
├── QUICKSTART.md              # Reference: Quick start
├── SLURM_GUIDE.md            # Reference: SLURM usage
├── detailed/                  # Detailed guides
│   ├── MASTER_SCRIPT_GUIDE.md
│   ├── NEW_PLOTS_GUIDE.md
│   ├── VISUALIZATION_GUIDE.md
│   ├── LOG_FILES_GUIDE.md
│   └── Methodology_readme.md
├── implementation/            # Technical implementation
│   ├── IMPLEMENTATION_SUMMARY_FEB17.md
│   ├── PIPELINE_CONSOLIDATION_SUMMARY.md
│   ├── STEP26_IMPLEMENTATION_SUMMARY.md
│   ├── CONFIGURATION_VERIFICATION.md
│   └── PLOT_COMPARISON_EVSCOPE_VS_MOUSE.md
└── archive/                   # Historical documents
    ├── PARTITION_UPDATE_SUMMARY.md
    ├── PIPELINE_STATUS.md
    ├── VISUALIZATION_FIX_SUMMARY.md
    └── PIPELINE_OVERVIEW.md
```

## When to Use Which Document

### I want to...

**...get started quickly**
→ `../README.md` (Quick Start section)

**...understand what each configuration option does**
→ `detailed/MASTER_SCRIPT_GUIDE.md`

**...interpret the QC plots**
→ `detailed/NEW_PLOTS_GUIDE.md` (Top genes, RNA distribution)  
→ `detailed/VISUALIZATION_GUIDE.md` (Coverage plots)

**...troubleshoot a problem**
→ `../README.md` (Troubleshooting section)  
→ `detailed/LOG_FILES_GUIDE.md` (Find relevant logs)

**...change the adapter sequence**
→ `../README.md` (Adapter Sequences table)

**...use SLURM commands**
→ `SLURM_GUIDE.md`

**...understand the methodology**
→ `detailed/Methodology_readme.md`

**...see implementation details**
→ `implementation/` directory

**...view historical changes**
→ `archive/` directory

## Recently Updated

- **February 17, 2026:** Created master script, consolidated documentation
- **February 17, 2026:** Implemented expression QC plots
- **February 17, 2026:** Fixed coverage visualization

---

**Return to main documentation:** `../README.md`
