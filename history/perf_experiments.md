Perf experiments (reverted)

Summary:
I tried additional optimizations to reduce allocations and speed async/pool paths, but the
benchmarks regressed throughput for worker_pool at 10k and 50k. The code changes were
reverted to keep the faster baseline. This file records what was attempted and why.

Changes tried:
1) Pattern cache for match_list to avoid repeated Pattern.parse.
2) Pre-normalize haystacks and needles once per batch, then use pre-normalized match paths.
3) ASCII prefilter path in Matcher to reduce char allocations for ASCII-only inputs.

Why:
- Reduce per-item allocations (pattern parsing, unicode normalization).
- Reduce char array creation (prefilter and fuzzy match).
- Reduce repeated work across concurrent workers.

Benchmark impact (BENCH_DATASET=10000 and 50000, --release -Dmt, worker_pool):
- 10k: sequential dropped from ~89 IPS to ~76 IPS; pools also dropped to 67-74 IPS.
- 50k: sequential dropped from ~17.9 IPS to ~15 IPS; pools to ~14.4-14.8 IPS.
- Memory/op decreased (about 13MB -> 9MB for 10k), but throughput regression was larger.

Conclusion:
The normalization + ASCII prefilter approach reduced memory but hurt throughput. Keeping
the previous implementation is faster overall, so the changes were reverted.
