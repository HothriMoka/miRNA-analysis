#!/bin/bash
#
# monitor_test.sh - Monitor the RSEM + EMapper test job
#
# Usage: bash monitor_test.sh
#

JOB_ID=900261
LOG_FILE="logs/test_rsem_emapper_${JOB_ID}.log"

echo "===================================="
echo "Monitoring Test Job: ${JOB_ID}"
echo "===================================="
echo ""

# Check job status
echo "Job Status:"
squeue -j ${JOB_ID} -o "%.18i %.9P %.30j %.8u %.8T %.10M %.9l %.6D %.10R" 2>/dev/null || echo "Job completed or not found"
echo ""

# Check log file
if [[ -f "${LOG_FILE}" ]]; then
    echo "Recent Log Output:"
    echo "------------------------------------"
    tail -50 ${LOG_FILE}
    echo "------------------------------------"
    echo ""
    
    # Check for key milestones
    echo "Pipeline Progress:"
    echo "  [$(grep -q "Step 1:" ${LOG_FILE} && echo "✓" || echo " ")] FastQC"
    echo "  [$(grep -q "Step 2:" ${LOG_FILE} && echo "✓" || echo " ")] Trimming"
    echo "  [$(grep -q "Step 3:" ${LOG_FILE} && echo "✓" || echo " ")] STAR alignment"
    echo "  [$(grep -q "Step 4:" ${LOG_FILE} && echo "✓" || echo " ")] RSEM quantification"
    echo "  [$(grep -q "Step 5:" ${LOG_FILE} && echo "✓" || echo " ")] featureCounts"
    echo "  [$(grep -q "Step 10:" ${LOG_FILE} && echo "✓" || echo " ")] EMapper"
    echo ""
    
    # Check for errors
    if grep -qi "error\|fail\|bgzf.*assert" ${LOG_FILE} 2>/dev/null; then
        echo "⚠️  ERRORS DETECTED:"
        grep -i "error\|fail\|bgzf.*assert" ${LOG_FILE} | tail -10
        echo ""
    fi
    
    # Check RSEM specifically
    if grep -q "RSEM complete" ${LOG_FILE} 2>/dev/null; then
        echo "✅ RSEM completed successfully!"
    elif grep -q "Running RSEM" ${LOG_FILE} 2>/dev/null; then
        echo "⏳ RSEM is running..."
    fi
    
    # Check EMapper specifically
    if grep -q "EMapper complete" ${LOG_FILE} 2>/dev/null; then
        echo "✅ EMapper completed successfully!"
    elif grep -q "Running EMapper" ${LOG_FILE} 2>/dev/null; then
        echo "⏳ EMapper is running (this can take 10-30 min)..."
    fi
    
else
    echo "Log file not yet created: ${LOG_FILE}"
    echo "Job is pending or just started."
fi

echo ""
echo "===================================="
echo "To monitor in real-time:"
echo "  tail -f ${LOG_FILE}"
echo "===================================="
