#!/bin/bash
# Quick test to verify EMapper dependencies

echo "Testing EMapper dependencies..."
echo "================================"

# Load environment
source /home/hmoka2/miniconda3/etc/profile.d/conda.sh
conda activate smallrna-tools

# Test Python modules
echo ""
echo "Checking Python modules:"
python3 << 'EOF'
import sys
print(f"Python version: {sys.version}")

try:
    import pyBigWig
    print(f"✓ pyBigWig: {pyBigWig.__version__}")
except ImportError as e:
    print(f"✗ pyBigWig: NOT FOUND - {e}")
    sys.exit(1)

try:
    import numba
    print(f"✓ numba: {numba.__version__}")
except ImportError as e:
    print(f"✗ numba: NOT FOUND - {e}")
    sys.exit(1)

try:
    import pysam
    print(f"✓ pysam: {pysam.__version__}")
except ImportError as e:
    print(f"✗ pysam: NOT FOUND - {e}")
    sys.exit(1)

try:
    import psutil
    print(f"✓ psutil: {psutil.__version__}")
except ImportError as e:
    print(f"✗ psutil: NOT FOUND - {e}")
    sys.exit(1)

try:
    import numpy
    print(f"✓ numpy: {numpy.__version__}")
except ImportError as e:
    print(f"✗ numpy: NOT FOUND - {e}")
    sys.exit(1)

print("\n✓ All dependencies available!")
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "✓ EMapper is ready to use!"
    echo "================================"
else
    echo ""
    echo "================================"
    echo "✗ Some dependencies are missing"
    echo "================================"
    exit 1
fi
