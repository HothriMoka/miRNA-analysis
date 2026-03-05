#!/usr/bin/env python3
"""
Generate comprehensive miRNA detection summary plots across all samples

Usage:
    python plot_mirna_detection_summary.py --input_dir OUTPUT_DIR --output mirna_summary.pdf
    
This script:
1. Scans all sample directories for miRNA detection results
2. Creates a summary plot with:
   - Left panel: GENCODE annotation statistics
   - Right panel: Per-sample miRNA detection rates
3. Generates statistics table
"""

import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
import argparse
import sys
import glob

# GENCODE M38 annotation statistics (GRCm39 mouse reference)
TOTAL_MIRNAS = 2201
CANONICAL_MIRNAS = 1189  # Mir* prefix genes
PREDICTED_MIRNAS = 1012  # Gm* prefix genes

def parse_args():
    parser = argparse.ArgumentParser(
        description='Generate miRNA detection summary plot across all samples'
    )
    parser.add_argument(
        '--input_dir',
        required=True,
        help='Base directory containing *_output subdirectories'
    )
    parser.add_argument(
        '--output',
        required=True,
        help='Output PDF file path'
    )
    parser.add_argument(
        '--min_tpm',
        type=float,
        default=0,
        help='Minimum TPM threshold for detection (default: 0)'
    )
    return parser.parse_args()

def find_mirna_files(base_dir):
    """Find all miRNA featureCounts TSV files in sample directories.

    This version is configured to use the per-sample
    '*_miRNAs_only_featureCounts.tsv' tables, which already contain
    TPM values computed from featureCounts output.
    """
    pattern = f"{base_dir}/*_output/04_expression/*_miRNAs_only_featureCounts.tsv"
    files = glob.glob(pattern)
    
    if not files:
        print(f"ERROR: No miRNA files found matching: {pattern}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(files)} sample miRNA files")
    return sorted(files)

def count_detected_mirnas(file_path, min_tpm=0):
    """Count detected miRNAs (TPM > threshold) in a sample"""
    try:
        df = pd.read_csv(file_path, sep='\t')
        
        # Check for TPM column
        if 'TPM' not in df.columns:
            print(f"WARNING: No TPM column in {file_path}", file=sys.stderr)
            return 0
        
        # Count miRNAs above threshold
        detected = (df['TPM'] > min_tpm).sum()
        return detected
    
    except Exception as e:
        print(f"ERROR reading {file_path}: {e}", file=sys.stderr)
        return 0

def extract_sample_name(file_path):
    """Extract sample name from file path"""
    # Example: /path/SAMPLE_output/04_expression/SAMPLE_miRNAs_only_RSEM.tsv
    parts = Path(file_path).parts
    for part in parts:
        if part.endswith('_output'):
            return part.replace('_output', '')
    return Path(file_path).stem.replace('_miRNAs_only_RSEM', '')

def create_summary_plot(detection_data, output_file, min_tpm=0):
    """Create comprehensive miRNA detection summary plot"""
    
    # Create DataFrame and sort by detection
    df = pd.DataFrame(detection_data)
    df_sorted = df.sort_values('Detected_miRNAs', ascending=False).reset_index(drop=True)
    
    # Create figure with 2 subplots
    fig = plt.figure(figsize=(20, 9))
    gs = fig.add_gridspec(1, 2, width_ratios=[1, 2.5], hspace=0.3, wspace=0.3)
    
    # ============================================================
    # LEFT PANEL: GENCODE Annotation Summary
    # ============================================================
    ax1 = fig.add_subplot(gs[0])
    
    categories = ['Total\nAnnotated', 'Canonical\n(Mir*)', 'Predicted\n(Gm*)']
    counts = [TOTAL_MIRNAS, CANONICAL_MIRNAS, PREDICTED_MIRNAS]
    colors_annot = ['#2E86AB', '#A23B72', '#F18F01']
    
    bars1 = ax1.bar(categories, counts, color=colors_annot, edgecolor='black', linewidth=1.5)
    
    # Add value labels on bars
    for bar, count in zip(bars1, counts):
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                 f'{int(count)}\n({count/TOTAL_MIRNAS*100:.1f}%)',
                 ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    ax1.set_ylabel('Number of miRNA Genes', fontsize=13, fontweight='bold')
    ax1.set_title('GENCODE M38 miRNA Annotation\n(GRCm39 Reference)', 
                  fontsize=14, fontweight='bold', pad=15)
    ax1.set_ylim(0, TOTAL_MIRNAS * 1.15)
    ax1.grid(axis='y', alpha=0.3, linestyle='--')
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)
    
    # ============================================================
    # RIGHT PANEL: Per-Sample Detection
    # ============================================================
    ax2 = fig.add_subplot(gs[1])
    
    x_pos = np.arange(len(df_sorted))
    colors_samples = plt.cm.viridis(df_sorted['Detected_miRNAs'] / df_sorted['Detected_miRNAs'].max())
    
    bars2 = ax2.bar(x_pos, df_sorted['Detected_miRNAs'], color=colors_samples, 
                    edgecolor='black', linewidth=0.5)
    
    # Add horizontal reference lines
    ax2.axhline(y=TOTAL_MIRNAS, color='red', linestyle='--', linewidth=2, 
                label=f'Total Annotated ({TOTAL_MIRNAS})', alpha=0.7)
    ax2.axhline(y=df_sorted['Detected_miRNAs'].mean(), color='orange', linestyle='--', 
                linewidth=2, label=f'Mean Detected ({df_sorted["Detected_miRNAs"].mean():.0f})', 
                alpha=0.7)
    
    # Customize x-axis - show ALL sample labels vertically
    ax2.set_xticks(x_pos)
    ax2.set_xticklabels(df_sorted['Sample'], rotation=90, ha='center', fontsize=7)
    
    ax2.set_xlabel('Sample ID (sorted by detection)', fontsize=12, fontweight='bold')
    tpm_label = f'TPM > {min_tpm}' if min_tpm > 0 else 'TPM > 0'
    ax2.set_ylabel(f'Number of miRNAs Detected ({tpm_label})', fontsize=12, fontweight='bold')
    ax2.set_title(f'miRNA Detection Across {len(df_sorted)} Samples\nRange: {df_sorted["Detected_miRNAs"].min()}-{df_sorted["Detected_miRNAs"].max()} miRNAs', 
                  fontsize=14, fontweight='bold', pad=15)
    ax2.set_ylim(0, TOTAL_MIRNAS * 1.1)
    ax2.legend(loc='upper right', fontsize=10)
    ax2.grid(axis='y', alpha=0.3, linestyle='--')
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)
    
    # Add statistics text box
    stats_text = f"""Detection Statistics:
Min: {df_sorted['Detected_miRNAs'].min()} ({df_sorted['Detected_miRNAs'].min()/TOTAL_MIRNAS*100:.1f}%)
Max: {df_sorted['Detected_miRNAs'].max()} ({df_sorted['Detected_miRNAs'].max()/TOTAL_MIRNAS*100:.1f}%)
Mean: {df_sorted['Detected_miRNAs'].mean():.0f} ({df_sorted['Detected_miRNAs'].mean()/TOTAL_MIRNAS*100:.1f}%)
Median: {df_sorted['Detected_miRNAs'].median():.0f} ({df_sorted['Detected_miRNAs'].median()/TOTAL_MIRNAS*100:.1f}%)"""
    
    ax2.text(0.02, 0.98, stats_text, transform=ax2.transAxes, 
             fontsize=9, verticalalignment='top', fontfamily='monospace',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
    
    # Overall title
    tpm_title = f' (TPM > {min_tpm})' if min_tpm > 0 else ''
    fig.suptitle(f'Mouse Small RNA-seq: miRNA Annotation and Detection Summary{tpm_title}', 
                 fontsize=16, fontweight='bold', y=0.98)
    
    # Save figure
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"✓ Plot saved: {output_file}")
    
    # Also save as PNG
    output_png = output_file.replace('.pdf', '.png')
    plt.savefig(output_png, dpi=300, bbox_inches='tight')
    print(f"✓ Plot saved: {output_png}")
    
    plt.close()
    
    return df_sorted

def print_summary_table(df_sorted, min_tpm=0):
    """Print detailed summary table"""
    print("\n" + "="*80)
    print("SAMPLE-BY-SAMPLE DETECTION SUMMARY")
    print("="*80)
    tpm_label = f'(TPM > {min_tpm})' if min_tpm > 0 else '(TPM > 0)'
    print(f"{'Sample':<25} {'Detected':<10} {'% of Annotated':<15} {'Category'}")
    print("-"*80)
    
    for idx, row in df_sorted.iterrows():
        detected = row['Detected_miRNAs']
        pct = detected / TOTAL_MIRNAS * 100
        
        # Categorize detection level
        if detected < 200:
            category = "Low"
        elif detected < 350:
            category = "Medium"
        else:
            category = "High"
        
        print(f"{row['Sample']:<25} {detected:<10} {pct:<15.2f} {category}")
    
    print("="*80)
    print(f"\nTotal samples analyzed: {len(df_sorted)}")
    print(f"GENCODE M38 total annotated miRNAs: {TOTAL_MIRNAS}")
    print(f"  - Canonical (Mir*): {CANONICAL_MIRNAS} ({CANONICAL_MIRNAS/TOTAL_MIRNAS*100:.1f}%)")
    print(f"  - Predicted (Gm*):  {PREDICTED_MIRNAS} ({PREDICTED_MIRNAS/TOTAL_MIRNAS*100:.1f}%)")
    print("="*80)

def main():
    args = parse_args()
    
    print("="*80)
    print("miRNA Detection Summary Plot Generator")
    print("="*80)
    print(f"Input directory: {args.input_dir}")
    print(f"Output file: {args.output}")
    print(f"Detection threshold: TPM > {args.min_tpm}")
    print()
    
    # Find all miRNA files
    mirna_files = find_mirna_files(args.input_dir)
    
    # Collect detection data
    detection_data = []
    for file_path in mirna_files:
        sample_name = extract_sample_name(file_path)
        detected = count_detected_mirnas(file_path, args.min_tpm)
        detection_data.append({
            'Sample': sample_name,
            'Detected_miRNAs': detected
        })
        print(f"  {sample_name}: {detected} miRNAs detected")
    
    if not detection_data:
        print("ERROR: No detection data collected", file=sys.stderr)
        sys.exit(1)
    
    print()
    
    # Create summary plot
    df_sorted = create_summary_plot(detection_data, args.output, args.min_tpm)
    
    # Print summary table
    print_summary_table(df_sorted, args.min_tpm)
    
    # Save CSV summary
    csv_output = args.output.replace('.pdf', '_data.csv')
    df_sorted.to_csv(csv_output, index=False)
    print(f"\n✓ Detection data saved: {csv_output}")
    
    print("\n✓ miRNA detection summary complete!")

if __name__ == '__main__':
    main()
