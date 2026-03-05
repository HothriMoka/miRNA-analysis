#!/usr/bin/env python3
"""
Create BED files for different RNA types from GTF annotation
"""

import argparse
import os
import sys

def gtf_to_bed(gtf_file, output_dir, rna_types):
    """Convert GTF to BED files, one per RNA type"""
    
    # Dictionary to store entries for each RNA type
    rna_entries = {rna_type: [] for rna_type in rna_types}
    
    print(f"Reading GTF: {gtf_file}")
    
    with open(gtf_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            
            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue
            
            # Only process gene entries
            if fields[2] != 'gene':
                continue
            
            chrom = fields[0]
            start = int(fields[3]) - 1  # GTF is 1-based, BED is 0-based
            end = int(fields[4])
            strand = fields[6]
            attributes = fields[8]
            
            # Extract gene_type
            gene_type = None
            gene_id = None
            gene_name = None
            
            for attr in attributes.split(';'):
                attr = attr.strip()
                if attr.startswith('gene_type'):
                    gene_type = attr.split('"')[1]
                elif attr.startswith('gene_id'):
                    gene_id = attr.split('"')[1]
                elif attr.startswith('gene_name'):
                    gene_name = attr.split('"')[1]
            
            if not gene_type or not gene_id:
                continue
            
            # Check if this gene_type matches any of our target types
            for rna_type in rna_types:
                if rna_type.lower() in gene_type.lower():
                    # BED format: chr start end name score strand
                    name = gene_name if gene_name else gene_id
                    bed_entry = f"{chrom}\t{start}\t{end}\t{name}\t0\t{strand}\n"
                    rna_entries[rna_type].append(bed_entry)
                    break
    
    # Write BED files
    os.makedirs(output_dir, exist_ok=True)
    
    for rna_type, entries in rna_entries.items():
        if not entries:
            print(f"WARNING: No {rna_type} genes found")
            continue
        
        output_file = os.path.join(output_dir, f"mm39_{rna_type}.bed")
        with open(output_file, 'w') as f:
            f.writelines(entries)
        
        print(f"✓ Created {output_file} ({len(entries)} genes)")
    
    return rna_entries

def main():
    parser = argparse.ArgumentParser(description='Create BED files for different RNA types from GTF')
    parser.add_argument('--gtf', required=True, help='Input GTF file')
    parser.add_argument('--output_dir', required=True, help='Output directory for BED files')
    parser.add_argument('--rna_types', nargs='+', 
                        default=['miRNA', 'tRNA', 'rRNA', 'snoRNA', 'snRNA', 'protein_coding', 'lncRNA'],
                        help='RNA types to extract')
    
    args = parser.parse_args()
    
    print("="*70)
    print("Creating BED files for RNA types")
    print("="*70)
    print(f"GTF file: {args.gtf}")
    print(f"Output directory: {args.output_dir}")
    print(f"RNA types: {', '.join(args.rna_types)}")
    print("")
    
    rna_entries = gtf_to_bed(args.gtf, args.output_dir, args.rna_types)
    
    print("")
    print("="*70)
    print("Summary")
    print("="*70)
    for rna_type in args.rna_types:
        count = len(rna_entries.get(rna_type, []))
        print(f"  {rna_type:20s}: {count:6d} genes")
    print("")
    print("✓ BED files created successfully!")

if __name__ == '__main__':
    main()
