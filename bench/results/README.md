# Benchmark Results

This directory stores benchmark results for tracking performance improvements and preventing regressions.

## Directory Structure

- `baseline/` - Baseline performance measurements
- `current/` - Current performance measurements
- `comparisons/` - Comparison reports between baseline and current
- `history/` - Historical results for trend analysis

## File Format

Results are stored as JSON files with the following structure:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "git_commit": "abc123def",
  "git_branch": "main",
  "benchmark_name": "parallel_matcher",
  "config": {
    "dataset_size": 10000,
    "haystack_size": 64,
    "needle": "test"
  },
  "results": {
    "100_items": {
      "empty_pattern": {
        "single_threaded": {"iterations_per_second": 10000, "allocation_bytes": 1024},
        "parallel_fuzzy_match": {"iterations_per_second": 15000, "allocation_bytes": 2048}
      }
    }
  }
}
```

## Usage

1. **Establish baseline**: Run benchmarks and save to `baseline/`
2. **Make changes**: Implement optimizations
3. **Run current benchmarks**: Save to `current/`
4. **Compare**: Generate comparison report
5. **Track**: Save successful improvements to `history/`

## Automation

Use the provided scripts:
- `bench/scripts/run_benchmarks.sh` - Run all benchmarks
- `bench/scripts/save_baseline.sh` - Save current results as baseline
- `bench/scripts/compare_results.sh` - Compare baseline vs current
- `bench/scripts/generate_report.sh` - Generate HTML report