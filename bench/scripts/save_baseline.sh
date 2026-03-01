#!/bin/bash
set -e

# Save current results as baseline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "Saving current results as baseline..."
echo

# Check if current results exist
if [ ! -d "bench/results/current" ]; then
    echo "Error: No current results found. Run benchmarks first."
    echo "Usage: ./bench/scripts/run_benchmarks.sh [benchmark]"
    exit 1
fi

# Create baseline directory
mkdir -p "bench/results/baseline"

# Copy current results to baseline
echo "Copying results from current to baseline..."
cp -r "bench/results/current/"* "bench/results/baseline/" 2>/dev/null || true

echo
echo "Baseline saved!"
echo "You can now make changes and run benchmarks again to compare."