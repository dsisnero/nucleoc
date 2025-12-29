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
- `BENCH_TOPK`: size of Top-K selection
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

### Sample Crystal Run (fast sanity)

Command:

```bash
CRYSTAL_CACHE_DIR=.crystal-cache BENCH_DATASET=2000 BENCH_SORT_SIZES=1000,5000 BENCH_CALC=1 BENCH_WARMUP=0.5 \\
  BENCH_TOPK=100 crystal run bench/src/main.cr --release -Dmt -- all
```

Notes:
- Worker pool was slower than sequential for this small dataset.
- MultiPattern parallel scoring was slower than sequential at this size.

### BoxcarVector Append

| Implementation | Dataset | IPS | Notes |
| --- | --- | --- | --- |
| Crystal boxcar push | 2000 | 70.31k | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal boxcar push_all | 2000 | 34.73k | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Rust boxcar (rayon) |  |  |  |

### ParSort Scaling

| Implementation | Size | IPS | CRYSTAL_WORKERS / Threads | Notes |
| --- | --- | --- | --- | --- |
| Crystal ParSort | 1000 | 91.44 | default | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal ParSort | 5000 | 2.48 | default | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Rust parallel sort |  |  |  |  |

### Worker Pool Throughput

| Implementation | Dataset | Workers | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal sequential matcher | 2000 | - | 405.36 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal spawn matcher | 2000 | - | 394.03 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber matcher | 2000 | - | 395.56 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 2000 | 1 | 401.91 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 2000 | 2 | 400.92 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 2000 | 4 | 400.50 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 2000 | 1 | 387.42 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 2000 | 2 | 398.54 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 2000 | 4 | 397.41 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Rust rayon worker pool |  |  |  |  |

### Worker Pool Throughput (dataset 10000)

| Implementation | Dataset | Workers | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal sequential matcher | 10000 | - | 89.48 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal spawn matcher | 10000 | - | 87.81 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber matcher | 10000 | - | 89.02 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 10000 | 1 | 89.52 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 10000 | 2 | 89.48 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 10000 | 4 | 88.81 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 10000 | 1 | 89.88 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 10000 | 2 | 89.74 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 10000 | 4 | 89.34 | BENCH_CALC=1 BENCH_WARMUP=0.5 |

### Worker Pool Throughput (dataset 50000)

| Implementation | Dataset | Workers | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal sequential matcher | 50000 | - | 17.93 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal spawn matcher | 50000 | - | 17.78 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber matcher | 50000 | - | 17.67 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 50000 | 1 | 17.95 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 50000 | 2 | 17.92 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal fiber pool | 50000 | 4 | 17.90 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 50000 | 1 | 17.92 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 50000 | 2 | 17.79 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal CML pool | 50000 | 4 | 17.70 | BENCH_CALC=1 BENCH_WARMUP=0.5 |

### MultiPattern Concurrent Matching

| Implementation | Dataset | Columns | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal score (sequential) | 2000 | 3 | 130.94 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal score_parallel | 2000 | 3 | 91.10 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Rust multi pattern |  |  |  |  |

### Top-K Selection

| Implementation | Size | K | IPS | Notes |
| --- | --- | --- | --- | --- |
| Crystal sort_snapshot | 1000 | 100 | 54.57 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal top_k_snapshot | 1000 | 100 | 4.32k | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal sort_snapshot | 5000 | 100 | 3.79 | BENCH_CALC=1 BENCH_WARMUP=0.5 |
| Crystal top_k_snapshot | 5000 | 100 | 4.13k | BENCH_CALC=1 BENCH_WARMUP=0.5 |

## Bottlenecks and Optimization Notes

-
-
-
