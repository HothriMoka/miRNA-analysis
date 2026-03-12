# Log Location Update

## Date: February 17, 2026

## Change Summary

**Moved master script logs from pipeline directory to output directory**

### Before
```
mouse_smallRNA-pipeline/
├── logs/                           # Master script logs here ❌
│   ├── 01_build_refs_*.log
│   ├── 02_SAMPLE_*.log
│   ├── 04_rsem_batch_*.log
│   ├── 05_emapper_*.log
│   └── 06_viz_*.log
└── ...
```

### After
```
mouse_smallRNA-pipeline/
└── logs/                           # Only individual script logs ✅

OUTPUT_DIR/
├── logs/                           # Master script logs here ✅
│   ├── 01_build_refs_*.log
│   ├── 02_SAMPLE_*.log
│   ├── 04_rsem_batch_*.log
│   ├── 05_emapper_*.log
│   ├── 06_viz_*.log
│   └── pipeline_jobs_*.txt
└── SAMPLE_output/
    └── logs/                       # Per-sample logs (unchanged)
```

## Rationale

### ✅ Benefits

**1. Keeps pipeline directory clean**
- Pipeline directory only contains scripts
- No generated/temporary files
- Easier version control

**2. Groups all outputs together**
- All results + logs in one place
- Easy to archive entire project
- Easy to delete/move project data

**3. Makes sense logically**
- Logs are outputs, not part of the pipeline code
- OUTPUT_DIR contains everything generated
- Clearer separation of code vs data

**4. Easier project management**
- Can delete entire OUTPUT_DIR to clean up
- Pipeline directory stays pristine
- Multiple projects can use same pipeline

### 📁 New Log Structure

```
OUTPUT_DIR/
├── logs/                                # Master script logs (NEW location)
│   ├── 01_build_refs_JOBID.log         # Reference building
│   ├── 02_SAMPLE_JOBID.log             # Individual sample processing
│   ├── 04_rsem_batch_JOBID.log         # RSEM batch
│   ├── 05_emapper_JOBID.log            # EMapper batch
│   ├── 06_viz_JOBID.log                # Visualization batch
│   └── pipeline_jobs_TIMESTAMP.txt     # Job tracking file
│
└── SAMPLE_output/
    ├── logs/                            # Per-sample detailed logs (unchanged)
    │   ├── SAMPLE_pipeline.log
    │   ├── rsem.log
    │   ├── emapper.log
    │   └── *.log
    └── 07_coverage_plots/
        ├── density_plot.log
        └── metagene_plot.log
```

## Changes Made

### Updated Files

**`Run_SmallRNA_Pipeline.sh`** - Changed all log paths:

1. **Created LOG_DIR variable:**
   ```bash
   LOG_DIR="${OUTPUT_BASE_DIR}/logs"
   ```

2. **Updated all SBATCH output/error paths:**
   ```bash
   #SBATCH --output=${LOG_DIR}/01_build_refs_%j.log     # Was: logs/
   #SBATCH --output=${LOG_DIR}/02_SAMPLE_%j.log         # Was: logs/
   #SBATCH --output=${LOG_DIR}/04_rsem_batch_%j.log     # Was: logs/
   #SBATCH --output=${LOG_DIR}/05_emapper_%j.log        # Was: logs/
   #SBATCH --output=${LOG_DIR}/06_viz_%j.log            # Was: logs/
   ```

3. **Updated job tracking file location:**
   ```bash
   cat > "${LOG_DIR}/pipeline_jobs_*.txt"   # Was: ${SCRIPT_DIR}/logs/
   ```

4. **Updated monitoring commands in output:**
   ```bash
   tail -f ${LOG_DIR}/04_rsem_batch_*.log   # Was: logs/
   ```

**`README.md`** - Updated log locations in monitoring section

### Not Changed

**Individual scripts (04, 05, 06)** keep their existing log behavior:
- Their own SBATCH headers still use `logs/` (in pipeline directory)
- BUT when called from master script, master script overrides the paths
- Can still be run independently with their default log location

**Per-sample logs** (in `SAMPLE_output/logs/`) remain unchanged:
- These are detailed step-by-step logs
- Created by script 02
- Still in sample output directories

## Usage

### View Master Script Logs

```bash
cd OUTPUT_DIR/logs/

# View specific log
tail -f 04_rsem_batch_JOBID.log

# View all logs
ls -lht
```

### View Per-Sample Logs

```bash
cd OUTPUT_DIR/SAMPLE_output/logs/

# View pipeline log
cat SAMPLE_pipeline.log

# View RSEM log
cat rsem.log
```

## Migration

### For Current Users

**Logs from today forward:** Will be in `OUTPUT_DIR/logs/`

**Old logs:** Still in `pipeline_directory/logs/`
- These are from manual script submissions
- They don't interfere with new structure
- Can be archived or deleted if no longer needed

### Cleanup Old Logs (Optional)

```bash
cd /home/hmoka2/.../mouse_smallRNA-pipeline/logs/

# Archive old logs
tar -czf old_logs_$(date +%Y%m%d).tar.gz *.log *.err

# Or delete if not needed
rm *.log *.err
```

## Benefits Summary

| Aspect | Before | After | Benefit |
|--------|--------|-------|---------|
| **Pipeline dir** | Contains logs | Clean, code only | ✅ Cleaner |
| **Output dir** | No master logs | All logs here | ✅ Organized |
| **Project archival** | Logs scattered | All in OUTPUT_DIR | ✅ Easier |
| **Version control** | Logs mixed with code | Separate | ✅ Better |
| **Multi-project** | Logs conflict | Isolated | ✅ Safer |

## Verification

**Tested:** Script updated and verified  
**Impact:** No breaking changes - all paths updated consistently  
**Backward compat:** Individual scripts still work independently  

## Summary

✅ **Master script logs → OUTPUT_DIR/logs/**  
✅ **Pipeline directory stays clean**  
✅ **All outputs grouped together**  
✅ **Easier project management**  
✅ **README updated with new locations**  

**Result:** Better organized, cleaner structure, easier to use! 🎉

---

**Status:** ✅ COMPLETE  
**Breaking changes:** None  
**User action:** None required (automatic)
