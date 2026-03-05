#!/usr/bin/env python3
"""
Top Expressed Genes Plot (Mouse smallRNA Pipeline Version)

Generates a horizontal bar plot showing the top highly expressed genes,
grouped and colored by gene type. Helps identify:
- Dominant genes (ribosomal, housekeeping)
- Potential contamination (rRNA, mtRNA)
- Sample quality issues

Adapted from EVscope for mouse pipeline.
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import argparse
import matplotlib as mpl
import re

# Set PDF font type for vector graphics
mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['font.family'] = 'Arial'

def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Plot top-expressing genes by type, sorted by mean expression.'
    )
    parser.add_argument('--input', required=True, 
                       help='Input TSV: GeneID, GeneSymbol, GeneType, ReadCounts, TPM')
    parser.add_argument('--output_pdf', required=True, 
                       help='Output PDF file')
    parser.add_argument('--output_png', required=True, 
                       help='Output PNG file')
    parser.add_argument('--genes_per_type', type=int, default=3,
                       help='Top genes per gene type (default: 3)')
    parser.add_argument('--total_genes', type=int, default=50,
                       help='Total genes to display (default: 50)')
    parser.add_argument('--sample_name', required=True,
                       help='Sample name for plot title')
    return parser.parse_args()

def read_expression_matrix(file_path):
    """Read expression matrix"""
    df = pd.read_csv(file_path, sep='\t', header=0)
    
    # Rename TPM to Norm_Expr for consistency
    if 'TPM' in df.columns:
        df['Norm_Expr'] = df['TPM']
    
    # Ensure numeric types
    df['Norm_Expr'] = pd.to_numeric(df['Norm_Expr'], errors='coerce')
    
    # Filter for expressed genes (TPM > 0)
    df = df[df['Norm_Expr'] > 0].copy()
    
    return df

def create_gene_label(row):
    """Create gene label: GeneSymbol or GeneSymbol(GeneID) if different"""
    gene_symbol = str(row['GeneSymbol']).strip()
    gene_id = str(row['GeneID']).strip()
    
    # Remove version numbers for comparison
    base_symbol = re.sub(r'\.\d+$', '', gene_symbol)
    base_id = re.sub(r'\.\d+$', '', gene_id)
    
    # If base names match, use symbol only; otherwise include ID
    if base_symbol == base_id:
        return base_symbol
    else:
        return f"{gene_symbol} ({gene_id})"

def select_top_genes(df, genes_per_type, total_genes):
    """Select top N genes per type, up to total_genes limit"""
    
    # Check if enough genes are available
    total_available = len(df)
    target_num = min(total_genes, total_available)
    
    # Sort by expression
    df_sorted = df.sort_values('Norm_Expr', ascending=False)
    
    # Select top N genes per GeneType
    top_per_type = df_sorted.groupby('GeneType').head(genes_per_type).reset_index(drop=True)
    
    # If we have enough, we're done
    if len(top_per_type) >= target_num:
        final_selection = top_per_type.head(target_num)
    else:
        # Supplement with overall top genes
        selected_gene_ids = top_per_type['GeneID'].tolist()
        remaining_df = df_sorted[~df_sorted['GeneID'].isin(selected_gene_ids)]
        additional_needed = target_num - len(top_per_type)
        additional_genes = remaining_df.head(additional_needed)
        final_selection = pd.concat([top_per_type, additional_genes])
    
    return final_selection

def sort_genes_by_type_mean(df):
    """Sort genes by mean expression per type, then by individual expression"""
    
    # Calculate mean expression per gene type
    mean_expr_per_type = df.groupby('GeneType')['Norm_Expr'].mean().reset_index()
    mean_expr_per_type = mean_expr_per_type.sort_values('Norm_Expr', ascending=False)
    
    # Sort genes by type order, then by expression
    type_order = mean_expr_per_type['GeneType'].tolist()
    df['GeneType'] = pd.Categorical(df['GeneType'], categories=type_order, ordered=True)
    df = df.sort_values(['GeneType', 'Norm_Expr'], ascending=[True, False])
    
    return df, type_order

def assign_colors(type_order):
    """Assign distinct colors to gene types"""
    n_types = len(type_order)
    
    # Use tab20 and tab20b for up to 40 colors
    colors_tab20 = plt.cm.tab20(np.linspace(0, 1, 20))
    colors_tab20b = plt.cm.tab20b(np.linspace(0, 1, 20))
    all_colors = np.vstack([colors_tab20, colors_tab20b])
    
    type_to_color = {t: all_colors[i % len(all_colors)] for i, t in enumerate(type_order)}
    
    return type_to_color

def create_plot(df, type_to_color, sample_name, genes_per_type, output_pdf, output_png):
    """Create horizontal bar plot"""
    
    # Create gene labels
    df['label'] = df.apply(create_gene_label, axis=1)
    
    # Assign colors
    color_list = [type_to_color[t] for t in df['GeneType']]
    
    # Create plot with dynamic height
    fig_height = max(8, 0.15 * len(df))  # At least 8 inches, scale with gene count
    fig, ax = plt.subplots(figsize=(10, fig_height))
    
    # Create horizontal bars
    y_pos = np.arange(len(df))
    ax.barh(y_pos, df['Norm_Expr'], color=color_list, height=0.7, 
            edgecolor='white', linewidth=0.5)
    
    # Configure axes
    ax.set_yticks(y_pos)
    ax.set_yticklabels(df['label'], fontsize=8)
    ax.invert_yaxis()  # Highest expression at top
    ax.set_xlabel('Expression Level (TPM)', fontsize=12, fontweight='bold')
    ax.set_xscale('log')  # Log scale for better visualization
    ax.grid(axis='x', alpha=0.3, linestyle='--')
    ax.set_facecolor('#F5F5F5')
    
    # Title
    ax.set_title(
        f"{sample_name}: Top {len(df)} Highly Expressed Genes\n"
        f"(Top {genes_per_type} per Gene Type, Sorted by Mean Expression)",
        fontsize=12, fontweight='bold', pad=15
    )
    
    # Create legend
    unique_types = df['GeneType'].unique()
    legend_patches = [mpatches.Patch(color=type_to_color[t], label=t, edgecolor='white') 
                      for t in unique_types]
    
    ax.legend(handles=legend_patches, 
              bbox_to_anchor=(1.02, 1), loc='upper left',
              title='Gene Type', fontsize=9, title_fontsize=10,
              frameon=True, fancybox=True, shadow=True)
    
    # Save outputs
    plt.tight_layout()
    plt.savefig(output_pdf, format='pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_png, format='png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"✓ Top genes plot saved:")
    print(f"  {output_pdf}")
    print(f"  {output_png}")

def print_summary(df, genes_per_type):
    """Print summary statistics"""
    print("\n" + "="*70)
    print("SUMMARY: TOP EXPRESSED GENES")
    print("="*70)
    print(f"Total genes displayed: {len(df)}")
    print(f"Gene types represented: {df['GeneType'].nunique()}")
    print(f"Top genes per type: {genes_per_type}")
    print("\nTop 10 genes by expression:")
    print("-" * 70)
    
    top10 = df.head(10)
    for i, (idx, row) in enumerate(top10.iterrows(), 1):
        print(f"{i:2d}. {row['label']:40s} {row['Norm_Expr']:10.2f} TPM ({row['GeneType']})")
    
    print("\nGene counts by type:")
    print("-" * 70)
    type_counts = df['GeneType'].value_counts()
    for gene_type, count in type_counts.items():
        print(f"  {gene_type:30s}: {count:3d} genes")
    print("="*70)

def main():
    args = parse_arguments()
    
    print(f"Reading expression matrix: {args.input}")
    df = read_expression_matrix(args.input)
    print(f"  Total expressed genes (TPM > 0): {len(df)}")
    print(f"  Unique gene types: {df['GeneType'].nunique()}")
    
    print(f"\nSelecting top {args.genes_per_type} genes per type...")
    selected_df = select_top_genes(df, args.genes_per_type, args.total_genes)
    print(f"  Selected {len(selected_df)} genes")
    
    print("\nSorting genes by gene type mean expression...")
    sorted_df, type_order = sort_genes_by_type_mean(selected_df)
    
    print("Assigning colors to gene types...")
    type_to_color = assign_colors(type_order)
    
    print("Creating plot...")
    create_plot(sorted_df, type_to_color, args.sample_name, args.genes_per_type,
                args.output_pdf, args.output_png)
    
    print_summary(sorted_df, args.genes_per_type)
    print("\n✓ Complete!")

if __name__ == '__main__':
    main()
