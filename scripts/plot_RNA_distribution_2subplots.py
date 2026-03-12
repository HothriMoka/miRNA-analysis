#!/usr/bin/env python3
"""
RNA Distribution Plot - 2 Subplots (Mouse smallRNA Pipeline Version)

Generates RNA composition plots showing:
- Left subplot: Long RNA types distribution
- Right subplot: Small RNA types distribution

Each subplot shows both absolute counts and percentages at different
expression thresholds to understand RNA composition.

Adapted from EVscope for mouse pipeline with simplified gene type categorization.
"""

import argparse
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch
from matplotlib.lines import Line2D
from collections import defaultdict

# Set global font
mpl.rcParams["font.family"] = "Arial"
mpl.rcParams['pdf.fonttype'] = 42

# Mouse-specific RNA type categorization (based on GENCODE mouse annotations)
SMALL_RNA_TYPES = ["miRNA", "tRNA", "snoRNA", "snRNA", "scaRNA", "scRNA", 
                   "ribozyme", "sRNA", "vaultRNA", "Y_RNA"]

LONG_RNA_TYPES = ["protein_coding", "lncRNA", "rRNA", "processed_pseudogene",
                  "unprocessed_pseudogene", "pseudogene", "TEC", "IG_C_gene",
                  "IG_D_gene", "IG_J_gene", "IG_V_gene", "TR_C_gene", "TR_D_gene",
                  "TR_J_gene", "TR_V_gene", "Mt_rRNA", "Mt_tRNA"]

# Color map for RNA types (using tab20 colormap)
def generate_color_map(rna_types):
    """Generate distinct colors for RNA types"""
    n_types = len(rna_types)
    # Use tab20 and tab20b for up to 40 colors
    colors_tab20 = plt.cm.tab20(np.linspace(0, 1, 20))
    colors_tab20b = plt.cm.tab20b(np.linspace(0, 1, 20))
    all_colors = np.vstack([colors_tab20, colors_tab20b])
    
    color_map = {}
    for i, rna_type in enumerate(rna_types):
        color_map[rna_type] = all_colors[i % len(all_colors)]
    return color_map

# Expression thresholds for filtering
TPM_THRESHOLDS = [0.001, 0.1, 0.5, 1, 5]
TPM_FILTER_LABELS = [
    "TPM > 0.001",
    "TPM > 0.1",
    "TPM > 0.5",
    "TPM > 1",
    "TPM > 5"
]

COUNT_THRESHOLDS = [1, 5, 10, 20, 50]
COUNT_FILTER_LABELS = [
    "Counts > 1",
    "Counts > 5",
    "Counts > 10",
    "Counts > 20",
    "Counts > 50"
]

def parse_arguments():
    parser = argparse.ArgumentParser(description="Generate RNA composition plots (2 subplots)")
    parser.add_argument("--input", required=True, 
                       help="Input TSV: GeneID, GeneSymbol, GeneType, ReadCounts, TPM")
    parser.add_argument("--output", required=True, 
                       help="Output file prefix (no extension)")
    parser.add_argument("--sample_name", required=True, 
                       help="Sample name for titles")
    return parser.parse_args()

def read_expression_matrix(file_path):
    """Read expression matrix and categorize RNA types"""
    df = pd.read_csv(file_path, sep='\t')
    
    # Rename TPM to Norm_Expr for consistency
    if 'TPM' in df.columns:
        df['Norm_Expr'] = df['TPM']
    
    # Ensure numeric types
    df['ReadCounts'] = pd.to_numeric(df['ReadCounts'], errors='coerce')
    df['Norm_Expr'] = pd.to_numeric(df['Norm_Expr'], errors='coerce')
    
    # Drop rows with invalid data
    df = df.dropna(subset=['ReadCounts', 'Norm_Expr', 'GeneType'])
    
    # Restrict to genes with sufficient support in this sample
    # (only keep genes with >10 raw counts)
    df = df[df['ReadCounts'] > 10].copy()
    
    return df

def generate_filter_data_by_metric(df, metric, thresholds):
    """Count genes by type at different expression thresholds"""
    filter_data = []
    for thresh in thresholds:
        type_counts = df[df[metric] > thresh]['GeneType'].value_counts().to_dict()
        filter_data.append(defaultdict(int, type_counts))
    return filter_data

def sort_rna_types(filter_data_list, rna_types):
    """Sort RNA types by total count across all filters"""
    totals = {rna: sum(d.get(rna, 0) for d in filter_data_list) for rna in rna_types}
    sorted_types = sorted([r for r in rna_types if totals[r] > 0], 
                         key=lambda r: totals[r], reverse=True)
    return sorted_types

def plot_side_counts(ax, filter_data, sorted_types, labels, color_map, is_left=True):
    """Plot absolute counts as stacked horizontal bars"""
    n_filters = len(labels)
    y_positions = np.arange(n_filters)
    bar_height = 0.8
    bottom = np.zeros(n_filters)
    
    for rna in sorted_types:
        counts = [d.get(rna, 0) for d in filter_data]
        ax.barh(y_positions, counts, left=bottom, height=bar_height,
                color=color_map.get(rna, '#CCCCCC'), edgecolor='white', linewidth=0.5)
        bottom += counts
    
    max_val = bottom.max() if bottom.max() > 0 else 1
    ax.set_xlim(0, max_val * 1.15)
    
    if is_left:
        ax.invert_xaxis()
    
    ax.grid(axis='x', alpha=0.3, linestyle='--')
    ax.set_facecolor('#F5F5F5')
    ax.set_yticks(y_positions)
    
    if is_left:
        ax.set_yticklabels(labels, fontsize=11, fontweight='bold')
        ax.tick_params(axis='y', pad=5)
    else:
        ax.set_yticklabels([])
    
    ax.set_xlabel('Gene Count', fontsize=11, fontweight='bold')

def plot_side_percentage(ax, filter_data, sorted_types, labels, color_map, is_left=True):
    """Plot percentages as stacked horizontal bars"""
    n_filters = len(labels)
    y_positions = np.arange(n_filters)
    bar_height = 0.8
    
    totals = [sum(d.get(r, 0) for r in sorted_types) for d in filter_data]
    totals = [t if t > 0 else 1 for t in totals]
    bottom = np.zeros(n_filters)
    
    for rna in sorted_types:
        counts = [d.get(rna, 0) for d in filter_data]
        percents = [(count/total)*100 for count, total in zip(counts, totals)]
        ax.barh(y_positions, percents, left=bottom, height=bar_height,
                color=color_map.get(rna, '#CCCCCC'), edgecolor='white', linewidth=0.5)
        bottom = [b + p for b, p in zip(bottom, percents)]
    
    ax.set_xlim(0, 100)
    
    if is_left:
        ax.invert_xaxis()
    
    ax.grid(axis='x', alpha=0.3, linestyle='--')
    ax.set_facecolor('#F5F5F5')
    ax.set_yticks(y_positions)
    
    if is_left:
        ax.set_yticklabels(labels, fontsize=11, fontweight='bold')
        ax.tick_params(axis='y', pad=5)
    else:
        ax.set_yticklabels([])
    
    ax.set_xticks([0, 25, 50, 75, 100])
    ax.set_xticklabels(["0%", "25%", "50%", "75%", "100%"])
    ax.set_xlabel('Percentage', fontsize=11, fontweight='bold')

def get_legend_handles(sorted_long, sorted_small, color_map):
    """Create legend handles"""
    dummy_long = Line2D([], [], color='none', label='Long RNA Types', 
                        marker='', linestyle='')
    dummy_small = Line2D([], [], color='none', label='Small RNA Types', 
                         marker='', linestyle='')
    
    long_handles = [Patch(facecolor=color_map.get(rt, '#CCCCCC'), label=rt, edgecolor='white') 
                    for rt in sorted_long]
    small_handles = [Patch(facecolor=color_map.get(rt, '#CCCCCC'), label=rt, edgecolor='white') 
                     for rt in sorted_small]
    
    empty_handle = Patch(facecolor='none', edgecolor='none', label='')
    
    return [dummy_long] + long_handles + [empty_handle] + [dummy_small] + small_handles

def create_combined_plots(filter_data_tpm, filter_data_counts, out_prefix, sample_name, 
                         sorted_long, sorted_small, color_map):
    """Create combined 4-row figure"""
    
    fig, axs = plt.subplots(nrows=4, ncols=2, figsize=(18, 26),
                            gridspec_kw={'hspace': 0.3, 'wspace': 0.15})
    fig.subplots_adjust(left=0.08, right=0.75, top=0.90, bottom=0.06)
    
    # Row 0: TPM Counts
    plot_side_counts(axs[0,0], filter_data_tpm, sorted_long, TPM_FILTER_LABELS, 
                    color_map, is_left=True)
    axs[0,0].set_title("Long RNAs", fontsize=13, fontweight='bold', pad=10)
    
    plot_side_counts(axs[0,1], filter_data_tpm, sorted_small, TPM_FILTER_LABELS, 
                    color_map, is_left=False)
    axs[0,1].set_title("Small RNAs", fontsize=13, fontweight='bold', pad=10)
    
    # Row 1: TPM Percentage
    plot_side_percentage(axs[1,0], filter_data_tpm, sorted_long, TPM_FILTER_LABELS, 
                        color_map, is_left=True)
    plot_side_percentage(axs[1,1], filter_data_tpm, sorted_small, TPM_FILTER_LABELS, 
                        color_map, is_left=False)
    
    # Row 2: ReadCounts Counts
    plot_side_counts(axs[2,0], filter_data_counts, sorted_long, COUNT_FILTER_LABELS, 
                    color_map, is_left=True)
    axs[2,0].set_title("Long RNAs", fontsize=13, fontweight='bold', pad=10)
    
    plot_side_counts(axs[2,1], filter_data_counts, sorted_small, COUNT_FILTER_LABELS, 
                    color_map, is_left=False)
    axs[2,1].set_title("Small RNAs", fontsize=13, fontweight='bold', pad=10)
    
    # Row 3: ReadCounts Percentage
    plot_side_percentage(axs[3,0], filter_data_counts, sorted_long, COUNT_FILTER_LABELS, 
                        color_map, is_left=True)
    plot_side_percentage(axs[3,1], filter_data_counts, sorted_small, COUNT_FILTER_LABELS, 
                        color_map, is_left=False)
    
    # Titles
    fig.text(0.5, 0.93,
             f"{sample_name}: RNA Type Composition by Expression Level (TPM)",
             ha='center', fontsize=16, fontweight='bold')
    fig.text(0.5, 0.48,
             f"{sample_name}: RNA Type Composition by Read Counts",
             ha='center', fontsize=16, fontweight='bold')
    
    # Legend
    handles = get_legend_handles(sorted_long, sorted_small, color_map)
    fig.legend(handles=handles, loc='center left', bbox_to_anchor=(0.77, 0.5),
               fontsize=11, frameon=True, fancybox=True, shadow=True)
    
    # Save outputs
    pdf_out = out_prefix + ".pdf"
    png_out = out_prefix + ".png"
    plt.savefig(pdf_out, dpi=300, bbox_inches='tight')
    plt.savefig(png_out, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"✓ RNA distribution plots saved:")
    print(f"  {pdf_out}")
    print(f"  {png_out}")

def main():
    args = parse_arguments()
    
    print(f"Reading expression matrix: {args.input}")
    df = read_expression_matrix(args.input)
    print(f"  Total genes: {len(df)}")
    print(f"  Unique gene types: {df['GeneType'].nunique()}")
    
    # Identify which RNA types are actually present
    all_types = set(df['GeneType'].unique())
    present_small = [t for t in SMALL_RNA_TYPES if t in all_types]
    present_long = [t for t in LONG_RNA_TYPES if t in all_types]
    
    # Add any types not in our predefined categories
    other_types = all_types - set(present_small) - set(present_long)
    if other_types:
        print(f"  Other types (added to long RNAs): {', '.join(other_types)}")
        present_long.extend(sorted(other_types))
    
    # Generate color map for all present types
    all_present_types = present_long + present_small
    color_map = generate_color_map(all_present_types)
    
    print("\nGenerating filter data...")
    # Generate filter data
    filter_data_tpm = generate_filter_data_by_metric(df, "Norm_Expr", TPM_THRESHOLDS)
    filter_data_counts = generate_filter_data_by_metric(df, "ReadCounts", COUNT_THRESHOLDS)
    
    # Sort RNA types by abundance
    combined_data = filter_data_tpm + filter_data_counts
    sorted_long = sort_rna_types(combined_data, present_long)
    sorted_small = sort_rna_types(combined_data, present_small)
    
    print(f"  Long RNA types detected: {len(sorted_long)}")
    print(f"  Small RNA types detected: {len(sorted_small)}")
    
    print("\nCreating plots...")
    create_combined_plots(filter_data_tpm, filter_data_counts, args.output, 
                         args.sample_name, sorted_long, sorted_small, color_map)
    
    print("✓ Complete!")

if __name__ == "__main__":
    main()
