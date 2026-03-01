# Nucleo Performance Optimization Plan

## Overview
This document outlines the plan for optimizing Nucleo async snapshot performance, including benchmarking harness creation and result tracking system.

## Epic Structure
- **Epic**: nucleoc-i8g - Nucleo async snapshot performance optimization epic
- **Subtasks**:
  1. nucleoc-nar: Core performance improvements
  2. nucleoc-i8g.1: Benchmarking harness
  3. nucleoc-i8g.2: Test result storage and comparison

## Current Performance Issues
Based on analysis of the codebase:

### 1. Empty Pattern Inefficiency
**Problem**: Empty patterns still score every item
**Solution**: Fast path that returns first N items with score 0
**Files to modify**: `src/nucleoc/api.cr`, `src/nucleoc/nucleo_native.cr`

### 2. Parallel Snapshot Overhead
**Problem**: `Array#each_slice` allocations per chunk
**Solution**: Single result channel, avoid slice allocations
**Files to modify**: `src/nucleoc/api.cr`

### 3. Sorting Inefficiency
**Problem**: Full sort even when only top-k needed
**Solution**: Keep top-k per chunk, reduce merge size
**Files to modify**: `src/nucleoc/api.cr`, `src/nucleoc/par_sort_native.cr`

### 4. Memory Usage
**Problem**: Duplicate data structures for parallel processing
**Solution**: Shared buffers, reuse allocations
**Files to modify**: `src/nucleoc/api.cr`, `src/nucleoc/worker_pool_fiber.cr`

## Benchmarking Strategy

### Test Sizes
- Small: 100-1k items (baseline)
- Medium: 10k items (target for parallel wins)
- Large: 50k-100k items (stress test)

### Pattern Types
1. **Empty pattern**: Should be instant (fast path)
2. **Simple pattern**: Single word, common prefix
3. **Complex pattern**: Multiple words, fuzzy matching
4. **No matches**: Pattern that matches nothing

### Metrics to Track
- **Time**: Matching duration (ms)
- **Memory**: Allocations, peak usage
- **Throughput**: Items/second
- **Speedup**: Parallel vs single-threaded ratio

## Implementation Plan

### Phase 1: Core Optimizations (nucleoc-nar)
1. **Empty pattern fast path** - O(1) return for empty patterns
2. **Chunking optimization** - Reduce allocations in parallel snapshot
3. **Top-k selection** - Partial sort when max_results specified
4. **ParSort integration** - Use parallel sort for large result sets

### Phase 2: Benchmarking Harness (nucleoc-i8g.1)
1. **Data generator** - Realistic test strings
2. **Benchmark runner** - Measure across sizes/configurations
3. **Statistical analysis** - Mean, median, stddev, confidence intervals
4. **Warm-up runs** - Avoid JIT compilation effects

### Phase 3: Result Management (nucleoc-i8g.2)
1. **JSON storage** - Results with metadata (commit, timestamp, version)
2. **Golden results** - Best-known performance baseline
3. **CI integration** - Automatic regression detection
4. **Visualization** - Performance trends over time

## Success Criteria

### Quantitative Goals
1. **Empty pattern**: < 1ms for any dataset size
2. **Parallel speedup**: ≥ 1.5x for 10k+ items
3. **Memory reduction**: 50% less allocations in parallel path
4. **Throughput**: > 100k items/second for simple patterns

### Qualitative Goals
1. **Consistency**: Parallel always faster than single-threaded above threshold
2. **Predictability**: Performance scales linearly with dataset size
3. **Reliability**: No memory leaks or resource exhaustion
4. **Maintainability**: Clear performance tracking and regression prevention

## Files to Create/Modify

### Core Code
- `src/nucleoc/api.cr` - Main optimization target
- `src/nucleoc/nucleo_native.cr` - Empty pattern fast path
- `src/nucleoc/par_sort_native.cr` - Top-k optimization
- `src/nucleoc/worker_pool_fiber.cr` - Memory optimization

### Benchmarking
- `bench/benchmarks/nucleo_snapshot.cr` - Main benchmark
- `bench/benchmarks/data_generator.cr` - Test data
- `bench/benchmarks/performance_test.cr` - Test runner
- `bench/benchmarks/results_manager.cr` - Result management

### CI/Results
- `.github/workflows/benchmark.yml` - CI integration
- `bench/benchmarks/results/` - JSON result storage
- `bench/benchmarks/golden/` - Best results
- `bench/benchmarks/compare_results.cr` - Comparison tool

## Testing Strategy

### Unit Tests
- Verify empty pattern fast path returns correct items
- Ensure parallel results match single-threaded
- Test edge cases (empty dataset, single item, max_results limits)

### Integration Tests
- Compare performance across sizes
- Verify memory doesn't leak
- Ensure thread safety in parallel operations

### Regression Tests
- CI fails on >10% performance regression
- Golden results updated only on verified improvements
- Historical tracking of all benchmark runs

## Timeline

### Week 1: Core Optimizations
- Implement empty pattern fast path
- Optimize chunking allocations
- Add top-k selection

### Week 2: Benchmarking Harness
- Create data generator
- Implement benchmark runner
- Add statistical analysis

### Week 3: Result Management
- Build JSON storage system
- Create golden results
- Integrate with CI

### Week 4: Validation & Polish
- Run comprehensive benchmarks
- Tune performance thresholds
- Document results and findings

## Risks & Mitigations

### Risk: Parallel overhead too high
**Mitigation**: Profile to identify bottlenecks, adjust chunk sizes, add minimum size threshold for parallelization

### Risk: Memory optimizations cause complexity
**Mitigation**: Keep simple baseline implementation, add optimizations as optional features

### Risk: Benchmarking adds maintenance burden
**Mitigation**: Automate result comparison, make benchmarks optional in CI, clear documentation

### Risk: Performance varies across hardware
**Mitigation**: Use relative metrics (speedup ratios), test on multiple platforms, set reasonable thresholds

## Conclusion
This plan provides a structured approach to optimizing Nucleo performance with measurable goals, clear implementation steps, and robust tracking to ensure improvements are maintained over time.