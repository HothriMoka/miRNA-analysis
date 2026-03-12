# Case Sensitivity Fix - February 17, 2026

## Issue

Script reported "ERROR: References not found" even though references directory existed.

```bash
$ bash Run_SmallRNA_Pipeline.sh
ERROR: References not found at /home/.../references
Please run with --build-references first
```

But references were actually present:
```bash
$ ls references/indices/
STAR/  RSEM/  bowtie2/
```

## Root Cause

**Case sensitivity mismatch in path check**

The script was checking for:
```bash
${REFERENCE_DIR}/indices/star/SAindex    # lowercase "star"
```

But the actual directory structure is:
```bash
${REFERENCE_DIR}/indices/STAR/SAindex    # uppercase "STAR"
```

This mismatch caused the file existence check `[ -f "..." ]` to fail, even though the file exists.

## Why This Happened

The `01_prepare_mouse_references.sh` script creates directories with uppercase `STAR`:
```bash
mkdir -p references/indices/STAR
STAR --runMode genomeGenerate --genomeDir references/indices/STAR ...
```

But the master script was checking for lowercase `star`.

## Fix Applied

Updated both reference checks in `Run_SmallRNA_Pipeline.sh`:

### Check 1: When building references (warning about existing)
```bash
# Before
if [ -f "${REFERENCE_DIR}/indices/star/SAindex" ]; then

# After
if [ -f "${REFERENCE_DIR}/indices/STAR/SAindex" ]; then
```

### Check 2: When skipping build (verify references exist)
```bash
# Before
if [ ! -f "${REFERENCE_DIR}/indices/star/SAindex" ]; then

# After
if [ ! -f "${REFERENCE_DIR}/indices/STAR/SAindex" ]; then
```

## Verification

**Before fix:**
```bash
$ bash Run_SmallRNA_Pipeline.sh
ERROR: References not found at .../references
```

**After fix:**
```bash
$ bash Run_SmallRNA_Pipeline.sh
✓ Using existing references at .../references

=== STEP 02-03: Processing Individual Samples ===
  Submitting 204913_S13_R1_001...
    Job ID: 900871
  ✓ Success
```

## Related Files

The actual directory structure (created by 01_prepare_mouse_references.sh):
```
references/
├── genome/
│   └── GRCm39.primary_assembly.genome.fa
├── annotations/
│   └── gencode.vM35.primary_assembly.annotation.gtf
├── bed_files/
│   ├── miRNA.bed
│   ├── tRNA.bed
│   └── ...
└── indices/
    ├── STAR/           ← Uppercase (correct)
    │   ├── SAindex
    │   ├── Genome
    │   └── ...
    ├── RSEM/
    │   ├── mouse_transcriptome.grp
    │   └── ...
    └── bowtie2/
        ├── mouse_genome.1.bt2
        └── ...
```

## Testing

Verified on system:
```bash
$ find references/indices/ -name "SAindex"
references/indices/STAR/SAindex    ← Uppercase directory

$ [ -f "references/indices/STAR/SAindex" ] && echo "Found"
Found                               ← Works now

$ [ -f "references/indices/star/SAindex" ] && echo "Found"
                                    ← No output (fails)
```

## Prevention

This highlights the importance of:

1. **Consistent naming conventions** - Stick to one case style
2. **Copy actual paths** - When adding checks, copy paths from working scripts
3. **Test on actual filesystem** - Verify file checks work
4. **Case-sensitive filesystems** - Linux is case-sensitive (star ≠ STAR)

## Impact

**Files changed:** 1
- `Run_SmallRNA_Pipeline.sh` (2 lines)

**Breaking changes:** None

**User action:** None (automatic)

## Summary

✅ **Fixed lowercase "star" → uppercase "STAR" in path checks**  
✅ **Script now correctly detects existing references**  
✅ **Pipeline runs without requiring --build-references**  
✅ **No impact on actual reference building (that was always correct)**  

---

**Status:** ✅ FIXED  
**Impact:** Bug fix only - no new features or breaking changes
