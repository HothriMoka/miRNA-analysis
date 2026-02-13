#!/usr/bin/env python3
"""
plot_genetype_barplot.py - Generate barplots of gene types from featureCounts TPM data

Usage:
    python plot_genetype_barplot.py --input featureCounts_TPM.tsv --output genetype_barplot.pdf
"""

import argparse
import sys
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import numpy as np

def parse_args():
    parser = argparse.ArgumentParser(
        description='Generate barplots of gene types from featureCounts TPM data'
    )
    parser.add_argument(
        '--input',
        required=True,
        help='Input featureCounts TPM file (TSV format with GeneType column)'
    )
    parser.add_argument(
        '--output',
        required=True,
        help='Output plot file (PDF or PNG)'
    )
    parser.add_argument(
        '--top',
        type=int,
        default=15,
        help='Number of top gene types to display (default: 15)'
    )
    parser.add_argument(
        '--title',
        default='Gene Type Distribution',
        help='Plot title'
    )
    parser.add_argument(
        '--min_tpm',
        type=float,
        default=0,
        help='Minimum TPM threshold for filtering genes (default: 0)'
    )
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Read input file
    print(f"Reading input file: {args.input}")
    try:
        df = pd.read_csv(args.input, sep='\t')
    except Exception as e:
        print(f"ERROR: Could not read input file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Check required columns
    if 'GeneType' not in df.columns:
        print("ERROR: 'GeneType' column not found in input file", file=sys.stderr)
        sys.exit(1)
    
    if 'TPM' not in df.columns:
        print("ERROR: 'TPM' column not found in input file", file=sys.stderr)
        sys.exit(1)
    
    # Filter by TPM if specified
    if args.min_tpm > 0:
        df_filtered = df[df['TPM'] > args.min_tpm].copy()
        print(f"Filtered to {len(df_filtered)} genes with TPM > {args.min_tpm}")
    else:
        df_filtered = df.copy()
    
    # Count gene types
    genetype_counts = df_filtered['GeneType'].value_counts()
    print(f"\nTotal gene types: {len(genetype_counts)}")
    print(f"Total genes: {genetype_counts.sum()}")
    
    # Get top N gene types
    top_genetypes = genetype_counts.head(args.top)
    
    # Create figure with two subplots
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Generate colors using matplotlib colormap
    cmap = plt.cm.get_cmap('tab20')
    colors = [cmap(i/len(top_genetypes)) for i in range(len(top_genetypes))]
    
    # Plot 1: Count barplot
    ax1.bar(range(len(top_genetypes)), top_genetypes.values, color=colors)
    ax1.set_xticks(range(len(top_genetypes)))
    ax1.set_xticklabels(top_genetypes.index, rotation=45, ha='right')
    ax1.set_xlabel('Gene Type', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Number of Genes', fontsize=12, fontweight='bold')
    ax1.set_title(f'{args.title}\n(Top {args.top} Gene Types)', fontsize=14, fontweight='bold')
    ax1.grid(axis='y', alpha=0.3, linestyle='--')
    
    # Add count labels on bars
    for i, (genetype, count) in enumerate(top_genetypes.items()):
        ax1.text(i, count, f'{int(count)}', ha='center', va='bottom', fontsize=9)
    
    # Plot 2: Percentage barplot
    genetype_pct = (genetype_counts / genetype_counts.sum() * 100).head(args.top)
    ax2.bar(range(len(genetype_pct)), genetype_pct.values, color=colors)
    ax2.set_xticks(range(len(genetype_pct)))
    ax2.set_xticklabels(genetype_pct.index, rotation=45, ha='right')
    ax2.set_xlabel('Gene Type', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Percentage (%)', fontsize=12, fontweight='bold')
    ax2.set_title(f'{args.title}\n(Top {args.top} Gene Types - Percentage)', fontsize=14, fontweight='bold')
    ax2.grid(axis='y', alpha=0.3, linestyle='--')
    
    # Add percentage labels on bars
    for i, (genetype, pct) in enumerate(genetype_pct.items()):
        ax2.text(i, pct, f'{pct:.1f}%', ha='center', va='bottom', fontsize=9)
    
    plt.tight_layout()
    
    # Save plot
    print(f"\nSaving plot to: {args.output}")
    try:
        plt.savefig(args.output, dpi=300, bbox_inches='tight')
        print("✓ Plot saved successfully!")
    except Exception as e:
        print(f"ERROR: Could not save plot: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Print summary statistics
    print("\n" + "="*60)
    print("SUMMARY STATISTICS")
    print("="*60)
    print(f"Total genes analyzed: {len(df_filtered)}")
    print(f"Total gene types: {len(genetype_counts)}")
    print(f"\nTop {args.top} gene types:")
    print("-" * 60)
    for i, (genetype, count) in enumerate(top_genetypes.items(), 1):
        pct = count / genetype_counts.sum() * 100
        print(f"{i:2d}. {genetype:35s} {int(count):8d} ({pct:5.2f}%)")
    print("="*60)

if __name__ == '__main__':
    main()
