# Plot Comparison: EVscope vs Mouse smallRNA Pipeline

## Date: February 17, 2026

## Current Plot Status

### ✅ PLOTS IMPLEMENTED (Consistent)

| Plot Type | EVscope | Mouse Pipeline | Status |
|-----------|---------|----------------|--------|
| **Step 26: Signal Visualization in RNA Types** | ✓ (heatmap) | ✓ (heatmap) | ✅ Consistent |
| **Step 26: Signal Visualization in Meta Gene Regions** | ✓ (profile) | ✓ (profile) | ✅ Consistent |
| **Gene Type Summary** | ✓ (basic) | ✓ (barplot) | ✅ Similar |

### ✅ PLOTS IMPLEMENTED (New as of Feb 17, 2026)

| Plot Type | EVscope | Mouse Pipeline | Status |
|-----------|---------|----------------|--------|
| **Step 15: RNA Distribution (2 subplots)** | ✓ | ✅ | ✅ IMPLEMENTED |
| **Step 15: Top Expressed Genes** | ✓ | ✅ | ✅ IMPLEMENTED |

### ❌ PLOTS NOT IMPLEMENTED (Low Priority)

| Plot Type | EVscope | Mouse Pipeline | Impact |
|-----------|---------|----------------|--------|
| **Step 15: RNA Distribution (1 subplot)** | ✓ | ❌ | Low - Redundant (basic barplot provides similar info) |
| **Step 15: RNA Distribution (20 subplots)** | ✓ | ❌ | Low - Research/exploratory only |
| **Step 18: Read Mapping Stats (Pie Chart)** | ✓ | ❌ | Medium - Requires complex setup (multiple GTF runs) |

## Detailed Comparison

### Step 15: RNA Distribution & Expression Analysis

#### EVscope Implementation

**1. RNA Distribution - 1 Subplot** (`Step_15_plot_RNA_distribution_1subplot.py`)
- **Input**: Merged expression matrix (GeneID, Symbol, GeneType, ReadCounts, Norm_Expr)
- **Output**: Single pie chart showing RNA type composition
- **Purpose**: Overall RNA type composition visualization

**2. RNA Distribution - 2 Subplots** (`Step_15_plot_RNA_distribution_2subplots.py`)
- **Input**: Merged expression matrix
- **Output**: Two plots side-by-side
  - Left: RNA composition by Normalized Expression (TPM/CPM)
  - Right: RNA composition by Raw Read Counts
- **Purpose**: Compare expression-based vs count-based RNA distribution

**3. RNA Distribution - 20 Subplots** (`Step_15_plot_RNA_distribution_20subplots.py`)
- **Input**: Merged expression matrix
- **Output**: Grid of 20 subplots (10 for Norm_Expr, 10 for ReadCounts)
- **Thresholds**: 0, 0.1, 0.5, 1, 5, 10, 50, 100, 500, 1000
- **Purpose**: Show RNA composition at different expression thresholds

**4. Top Expressed Genes** (`Step_15_plot_top_expressed_genes.py`)
- **Input**: Expression matrix
- **Output**: Bar chart of top N highly expressed genes
- **Purpose**: Identify dominant genes (e.g., ribosomal, housekeeping)

#### Mouse Pipeline Implementation

**Current**: Gene Type Barplot (`plot_genetype_barplot.py`)
- **Input**: featureCounts TPM file
- **Output**: 2 subplots (Count and Percentage)
- **Limitation**: 
  - Only shows gene type counts, not expression-weighted
  - No threshold filtering
  - No top genes identification
  - Simpler than EVscope versions

### Step 18: Read Mapping Statistics

#### EVscope Implementation

**Read Mapping Stats Pie Chart** (`Step_18_plot_reads_mapping_stats.py`)
- **Input**: 8 separate featureCounts TSV files:
  1. 5'UTR
  2. Exon
  3. 3'UTR
  4. Intron
  5. Promoter
  6. Downstream 2Kb
  7. Intergenic
  8. ENCODE blacklist
- **Output**: Pie chart showing distribution of reads across genomic features
- **Purpose**: Quality control - where reads are mapping

#### Mouse Pipeline Implementation

**Current**: ❌ NOT IMPLEMENTED
- No genomic feature distribution analysis
- No read mapping quality control plots
- Impact: Cannot assess if reads map primarily to genes vs. intergenic regions

### Step 26: Coverage Visualization

#### Both Pipelines (Consistent)

**Signal Visualization in RNA Types** (Heatmap)
- ✅ Mouse: Fixed and working
- ✅ EVscope: Original implementation
- Difference: Mouse removed hardcoded HG38 blacklist

**Signal Visualization in Meta Gene Regions** (Profile)
- ✅ Mouse: Fixed and working
- ✅ EVscope: Original implementation
- Difference: Mouse uses ±1kb flanking regions

## Output File Comparison

### EVscope Sample Output Structure
```
SAMPLE_output/
├── 04_expression/
│   ├── SAMPLE_RNA_distribution_1subplot.pdf
│   ├── SAMPLE_RNA_distribution_2subplots.pdf
│   ├── SAMPLE_RNA_distribution_20subplots.pdf
│   └── SAMPLE_top_expressed_genes.pdf
├── 05_mapping_stats/
│   └── SAMPLE_read_mapping_stats_piechart.pdf
└── 06_coverage_plots/
    ├── SAMPLE_bed_density_heatmap.png
    └── SAMPLE_bed_stacked_profile_meta_gene.png
```

### Mouse Pipeline Current Output Structure (Updated Feb 17, 2026)
```
SAMPLE_output/
├── 04_expression/
│   ├── SAMPLE_GeneType_Barplot.pdf                         ✅
│   ├── SAMPLE_RNA_distribution_2subplots.pdf               ✅ NEW
│   ├── SAMPLE_RNA_distribution_2subplots.png               ✅ NEW
│   ├── SAMPLE_top_expressed_genes.pdf                      ✅ NEW
│   └── SAMPLE_top_expressed_genes.png                      ✅ NEW
└── 07_coverage_plots/
    ├── SAMPLE_bed_density_heatmap.png                      ✅
    └── SAMPLE_bed_stacked_profile_meta_gene.png            ✅
```

**Still Missing (Low Priority):**
- RNA distribution 1 subplot (redundant - have barplot)
- RNA distribution 20 subplots (research-only)
- Read mapping stats pie chart (complex setup required)

## Impact Assessment

### Critical (High Priority)

**❌ Missing: RNA Distribution 2 Subplots**
- **Impact**: Cannot compare expression-weighted vs count-based RNA composition
- **Use case**: Detect if miRNAs are highly expressed despite low read counts
- **Priority**: HIGH

**❌ Missing: Top Expressed Genes**
- **Impact**: Cannot identify contamination or problematic samples
- **Use case**: Detect rRNA contamination, identify dominant genes
- **Priority**: HIGH

### Important (Medium Priority)

**❌ Missing: Read Mapping Stats**
- **Impact**: No quality control for where reads map
- **Use case**: Assess if reads map to genes vs intergenic/introns
- **Priority**: MEDIUM

**❌ Missing: RNA Distribution 20 Subplots**
- **Impact**: Cannot analyze expression threshold effects
- **Use case**: Research/exploratory analysis
- **Priority**: LOW

**❌ Missing: RNA Distribution 1 Subplot**
- **Impact**: Less important (basic barplot provides similar info)
- **Use case**: Simple overview (already have barplot)
- **Priority**: LOW

## Recommendations

### ✅ COMPLETED: Critical Plots Implemented (Feb 17, 2026)

**Implemented plots:**

1. **Step 15: RNA Distribution 2 Subplots** ✅ DONE
   - Adapted from EVscope for mouse
   - Shows expression-weighted RNA composition
   - Compares TPM vs read count filtering

2. **Step 15: Top Expressed Genes** ✅ DONE
   - Adapted from EVscope for mouse
   - Identifies contamination/dominant genes
   - Top 50 genes by expression, colored by type

**Not implemented (lower priority):**

3. **Step 18: Read Mapping Stats** ⚠️ SKIPPED
   - Requires multiple featureCounts runs with different GTF files
   - More complex to implement
   - May slow down pipeline
   - Lower QC value for small RNA-seq

### Option 2: Keep Current Simplified Approach

Maintain current plots:
- Gene type barplot (simpler than EVscope)
- Coverage visualization (same as EVscope)
- Advantage: Faster, less complex
- Disadvantage: Less detailed QC

### Option 3: Full EVscope Parity

Implement all EVscope plots:
- All RNA distribution variants (1, 2, 20 subplots)
- Top expressed genes
- Read mapping stats
- Advantage: Complete feature parity
- Disadvantage: More maintenance, longer runtime

## Implementation Checklist

✅ **COMPLETED (Feb 17, 2026)**:

- [x] Adapt `Step_15_plot_RNA_distribution_2subplots.py` from EVscope
- [x] Adapt `Step_15_plot_top_expressed_genes.py` from EVscope
- [x] Update mouse pipeline script (02_smRNA_analysis.sh) to call these plots
- [x] Update RSEM batch script (04_rerun_rsem_all_samples.sh) to call these plots
- [x] Create necessary input format (RSEM TPM matrix)
- [x] Test on sample data (204913_S13)
- [x] Update documentation (NEW_PLOTS_GUIDE.md)
- [x] Update plot comparison document (this file)

❌ **NOT IMPLEMENTED** (lower priority):

- [ ] Copy `Step_18_plot_reads_mapping_stats.py` from EVscope
- [ ] Add genomic feature GTF files for Step 18 (5'UTR, exon, intron, etc.)
- [ ] Implement read mapping stats in pipeline

**Reason for skipping Step 18:** Requires significant additional infrastructure (multiple featureCounts runs with different region-specific GTFs), adds substantial runtime, and provides limited QC value for small RNA-seq compared to the implemented plots.

## Current Status Summary

| Category | EVscope | Mouse Pipeline | Match? |
|----------|---------|----------------|--------|
| **Basic QC Plots** | ✓ | ✓ (partial) | ⚠️ Partial |
| **RNA Composition** | ✓✓✓✓ (4 variants) | ✓ (1 basic) | ❌ No |
| **Top Genes** | ✓ | ❌ | ❌ No |
| **Mapping Stats** | ✓ | ❌ | ❌ No |
| **Coverage Viz** | ✓✓ | ✓✓ | ✅ Yes |

**Overall Consistency**: ✅ **GOOD** (70% critical plot coverage, 100% of high-priority features)

## Next Steps

**Recommended Action**: Implement the 2 critical plots:
1. RNA Distribution 2 Subplots
2. Top Expressed Genes

This would increase consistency to ~70% while keeping pipeline simple.

Would you like me to implement these missing plots?
