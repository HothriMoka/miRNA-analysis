#!/usr/bin/env python3
"""
Extract gene metadata from GTF file.
Creates: GeneID, GeneSymbol, GeneType (TSV format)
Compatible with GENCODE GTF format.
"""

import argparse
import re
import sys
from collections import OrderedDict

def parse_gtf_attributes(attr_string):
    """Parse GTF attribute string into dictionary."""
    attrs = {}
    for item in attr_string.strip().split(';'):
        item = item.strip()
        if not item:
            continue
        match = re.match(r'(\S+)\s+"([^"]+)"', item)
        if match:
            key, value = match.groups()
            attrs[key] = value
    return attrs

def main():
    parser = argparse.ArgumentParser(
        description='Extract gene metadata from GENCODE GTF file'
    )
    parser.add_argument('--gtf', required=True, help='Input GTF file')
    parser.add_argument('--output', required=True, help='Output TSV file')
    args = parser.parse_args()
    
    print(f"Reading GTF file: {args.gtf}")
    
    # Store unique genes
    genes = OrderedDict()
    gene_types_count = {}
    
    try:
        with open(args.gtf, 'r') as f:
            for line_num, line in enumerate(f, 1):
                if line.startswith('#'):
                    continue
                
                fields = line.strip().split('\t')
                if len(fields) < 9:
                    continue
                
                feature = fields[2]
                if feature != 'gene':
                    continue
                
                attrs = parse_gtf_attributes(fields[8])
                gene_id = attrs.get('gene_id', 'NA')
                gene_name = attrs.get('gene_name', gene_id)
                gene_type = attrs.get('gene_type', attrs.get('gene_biotype', 'NA'))
                
                if gene_id != 'NA' and gene_id not in genes:
                    genes[gene_id] = (gene_name, gene_type)
                    gene_types_count[gene_type] = gene_types_count.get(gene_type, 0) + 1
                
                if line_num % 100000 == 0:
                    print(f"  Processed {line_num:,} lines...")
    
    except FileNotFoundError:
        print(f"ERROR: GTF file not found: {args.gtf}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to read GTF: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Write output
    print(f"Writing metadata to: {args.output}")
    try:
        with open(args.output, 'w') as out:
            out.write('GeneID\tGeneSymbol\tGeneType\n')
            for gene_id, (gene_name, gene_type) in genes.items():
                out.write(f'{gene_id}\t{gene_name}\t{gene_type}\n')
    except Exception as e:
        print(f"ERROR: Failed to write output: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Summary statistics
    print("\n=== Gene Metadata Summary ===")
    print(f"Total genes extracted: {len(genes):,}")
    print("\nTop 10 gene types:")
    for gene_type, count in sorted(gene_types_count.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {gene_type}: {count:,}")
    
    # Check for miRNAs specifically
    mirna_count = sum(count for gt, count in gene_types_count.items() if 'miRNA' in gt or 'mir' in gt.lower())
    print(f"\nmiRNA genes found: {mirna_count:,}")
    
    if mirna_count == 0:
        print("WARNING: No miRNA genes found! Check your GTF file.", file=sys.stderr)
    
    print("\nMetadata extraction complete!")

if __name__ == '__main__':
    main()
