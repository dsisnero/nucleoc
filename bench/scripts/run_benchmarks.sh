#!/bin/bash
set -e

# Run benchmarks and save results
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Default benchmark
BENCHMARK="${1:-parallel}"
OUTPUT_DIR="${2:-current}"
COMMIT_HASH="$(git rev-parse --short HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "Running benchmark: $BENCHMARK"
echo "Commit: $COMMIT_HASH ($BRANCH)"
echo "Timestamp: $TIMESTAMP"
echo "Output directory: bench/results/$OUTPUT_DIR"
echo

# Create output directory
mkdir -p "bench/results/$OUTPUT_DIR"

# Run benchmark
if [ "$BENCHMARK" = "all" ]; then
    echo "Running all benchmarks..."
    crystal run bench/src/main.cr --release -- all
else
    echo "Running benchmark: $BENCHMARK"
    crystal run bench/src/main.cr --release -- "$BENCHMARK"
fi

echo
echo "Benchmark completed!"
echo "Results saved to: bench/results/$OUTPUT_DIR/"