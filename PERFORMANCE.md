# Performance Benchmarks

This document captures benchmark results for Nucleoc's concurrent components and provides a template
for comparing Crystal CML.spawn performance against Rust nucleo's rayon benchmarks.

## Running Crystal Benchmarks

Use the benchmark harness under `bench/` and compile with `--release`.

```bash
CRYSTAL_CACHE_DIR=.crystal-cache crystal run bench/src/main.cr --release -- all
```

Target a specific benchmark:

```bash
BENCH_DATASET=20000 BENCH_CORES=1,2,4 crystal run bench/src/main.cr --release -- worker_pool
```

### Common Environment Variables

- `BENCH_DATASET`: number of rows for matching workloads
- `BENCH_HAYSTACK`: length of each haystack string
- `BENCH_NEEDLE`: needle string
- `BENCH_COLUMNS`: number of columns for MultiPattern
- `BENCH_CORES`: worker counts for worker pool benchmarks
- `BENCH_SORT_SIZES`: sizes for ParSort runs
- `BENCH_WARMUP`: Benchmark warmup seconds
- `BENCH_CALC`: Benchmark calculation seconds
- `CRYSTAL_WORKERS`: thread count for fiber scheduling (run separate processes per value)

## Running Rust nucleo Benchmarks

Clone the Rust nucleo repository and run its benchmark suite:

```bash
git clone https://github.com/helix-editor/nucleo.git
cd nucleo
cargo bench
```

Capture equivalent benchmark results where possible and record them in the tables below.

## Results

Record runs with: OS, CPU model, RAM, Crystal version, Rust version, and `CRYSTAL_WORKERS`.

### BoxcarVector Append

| Implementation | Dataset | IPS | Notes |
| --- | --- | --- | --- |
| Crystal boxcar push |  |  |  |
| Crystal boxcar push_all |  |  |  |
| Rust boxcar (rayon) |  |  |  |

### ParSort Scaling

| Implementation | Size | IPS | CRYSTAL_WORKERS / Threads | Notes |
| --- | --- | --- | --- | --- |
| Crystal ParSort |  |  |  |  |
| Rust parallel sort |  |  |  |  |

### Worker Pool Throughput

| Implementation | Dataset | Workers | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal sequential matcher |  |  |  |  |
| Crystal CML worker pool |  |  |  |  |
| Rust rayon worker pool |  |  |  |  |

### MultiPattern Concurrent Matching

| Implementation | Dataset | Columns | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal score (sequential) |  |  |  |  |
| Crystal score_parallel |  |  |  |  |
| Rust multi pattern |  |  |  |  |

## Bottlenecks and Optimization Notes

-
-
-
