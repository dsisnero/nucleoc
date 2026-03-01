#!/bin/bash
set -e

# Compare baseline vs current results
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "Comparing baseline vs current results..."
echo

# Check if baseline exists
if [ ! -d "bench/results/baseline" ]; then
    echo "Error: No baseline results found. Save baseline first."
    echo "Usage: ./bench/scripts/save_baseline.sh"
    exit 1
fi

# Check if current results exist
if [ ! -d "bench/results/current" ]; then
    echo "Error: No current results found. Run benchmarks first."
    echo "Usage: ./bench/scripts/run_benchmarks.sh [benchmark]"
    exit 1
fi

# Create comparison directory
mkdir -p "bench/results/comparisons"

# Find baseline and current files
BASELINE_FILES=$(find "bench/results/baseline" -name "*.json" -type f | sort)
CURRENT_FILES=$(find "bench/results/current" -name "*.json" -type f | sort)

if [ -z "$BASELINE_FILES" ]; then
    echo "Error: No JSON files found in baseline directory."
    exit 1
fi

if [ -z "$CURRENT_FILES" ]; then
    echo "Error: No JSON files found in current directory."
    exit 1
fi

echo "Baseline files:"
echo "$BASELINE_FILES" | sed 's/^/  /'
echo
echo "Current files:"
echo "$CURRENT_FILES" | sed 's/^/  /'
echo

# Simple comparison (for now - we'll implement proper comparison in Crystal)
echo "=== Simple File Comparison ==="
echo

for baseline_file in $BASELINE_FILES; do
    filename=$(basename "$baseline_file")
    current_file="bench/results/current/$filename"

    if [ -f "$current_file" ]; then
        echo "Comparing: $filename"

        # Extract basic info
        baseline_commit=$(jq -r '.git_commit' "$baseline_file" 2>/dev/null || echo "unknown")
        current_commit=$(jq -r '.git_commit' "$current_file" 2>/dev/null || echo "unknown")

        baseline_time=$(jq -r '.timestamp' "$baseline_file" 2>/dev/null || echo "unknown")
        current_time=$(jq -r '.timestamp' "$current_file" 2>/dev/null || echo "unknown")

        echo "  Baseline: $baseline_commit at $baseline_time"
        echo "  Current:  $current_commit at $current_time"

        # Check if same commit
        if [ "$baseline_commit" = "$current_commit" ]; then
            echo "  ⚠️  Same commit - no changes to compare"
        else
            echo "  ✅ Different commits - changes to analyze"
        fi

        echo
    else
        echo "Warning: No matching current file for $filename"
        echo
    fi
done

echo "=== Summary ==="
echo "For detailed comparison, run the Crystal comparison tool:"
echo "  crystal run bench/scripts/compare.cr --release"
echo
echo "Comparison results will be saved to: bench/results/comparisons/"