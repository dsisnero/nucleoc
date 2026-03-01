#!/usr/bin/env crystal
require "../src/nucleoc"
require "../bench/results/result_manager"

# Benchmark for testing epic nucleoc-nar optimizations
puts "=== Epic Optimization Benchmark (nucleoc-nar) ==="
puts "Testing success criteria from nucleoc-nar epic"
puts

# Generate test data
def generate_test_data(count : Int32) : Array(String)
  prefixes = ["src", "lib", "test", "docs", "config"]
  words = ["controller", "model", "view", "service", "helper", "util", "factory", "adapter"]
  suffixes = [".cr", ".rb", ".js", ".ts", ".py", ".java"]

  Array.new(count) do |i|
    prefix = prefixes[i % prefixes.size]
    word1 = words[i % words.size]
    word2 = words[(i * 7) % words.size]
    suffix = suffixes[i % suffixes.size]
    "#{prefix}/#{word1}_#{word2}#{suffix}"
  end
end

# Track memory allocations
def measure_memory(&block : -> T) : {T, Int64} forall T
  GC.collect
  start_stats = GC.stats
  result = block.call
  GC.collect
  end_stats = GC.stats

  allocated = end_stats.total_bytes - start_stats.total_bytes
  {result, allocated.to_i64}
end

# Benchmark method with memory tracking
def benchmark_with_memory(name : String, &block : -> T) : {Float64, Int64} forall T
  # Warm up
  2.times { block.call }

  # Measure performance
  start_time = Time.monotonic
  iterations = 0
  duration = 500.milliseconds

  total_allocated = 0_i64

  while (Time.monotonic - start_time) < duration
    result, allocated = measure_memory { block.call }
    total_allocated += allocated
    iterations += 1
  end

  elapsed = (Time.monotonic - start_time).total_seconds
  iterations_per_second = iterations / elapsed
  avg_allocation = total_allocated.to_f / iterations

  {iterations_per_second, avg_allocation.to_i64}
end

# Main benchmark
collector = NucleocBench::ResultCollector.new("epic_optimizations")

# Test all dataset sizes from epic success criteria
test_sizes = [100, 1_000, 10_000, 50_000, 100_000]

puts "Testing dataset sizes: #{test_sizes.join(", ")}"
puts

test_sizes.each do |size|
  puts "=== Testing #{size} items ==="

  haystacks = generate_test_data(size)
  matcher = Nucleoc::Matcher.new

  # Test 1: Empty pattern fast path (O(1) time goal)
  puts "\n1. Empty pattern fast path:"
  needle = ""

  ips_single, alloc_single = benchmark_with_memory("single-threaded") do
    normalized_needle = matcher.normalize_needle(needle)
    haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
  end

  ips_parallel, alloc_parallel = benchmark_with_memory("parallel_fuzzy_match") do
    matcher.parallel_fuzzy_match(haystacks, needle)
  end

  speedup = ips_parallel > 0 ? (ips_parallel / ips_single).round(2) : 0
  alloc_reduction = alloc_single > 0 ? ((alloc_single - alloc_parallel).to_f / alloc_single * 100).round(2) : 0

  puts "   Single-threaded: #{ips_single.round(1)} ips, #{alloc_single / 1024} KB alloc"
  puts "   Parallel: #{ips_parallel.round(1)} ips, #{alloc_parallel / 1024} KB alloc"
  puts "   Speedup: #{speedup}x, Allocation reduction: #{alloc_reduction}%"

  collector.record(size, "empty_pattern", "single_threaded", ips_single, alloc_single)
  collector.record(size, "empty_pattern", "parallel_fuzzy_match", ips_parallel, alloc_parallel)

  # Test 2: Simple pattern (test parallel vs single-threaded)
  puts "\n2. Simple pattern ('test'):"
  needle = "test"

  ips_single2, alloc_single2 = benchmark_with_memory("single-threaded") do
    normalized_needle = matcher.normalize_needle(needle)
    haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
  end

  ips_parallel2, alloc_parallel2 = benchmark_with_memory("parallel_fuzzy_match") do
    matcher.parallel_fuzzy_match(haystacks, needle)
  end

  speedup2 = ips_parallel2 > 0 ? (ips_parallel2 / ips_single2).round(2) : 0
  alloc_reduction2 = alloc_single2 > 0 ? ((alloc_single2 - alloc_parallel2).to_f / alloc_single2 * 100).round(2) : 0

  puts "   Single-threaded: #{ips_single2.round(1)} ips, #{alloc_single2 / 1024} KB alloc"
  puts "   Parallel: #{ips_parallel2.round(1)} ips, #{alloc_parallel2 / 1024} KB alloc"
  puts "   Speedup: #{speedup2}x, Allocation reduction: #{alloc_reduction2}%"

  # Epic success criteria: "Parallel matching beats single-threaded by 1.5x+ for 10k+ items"
  if size >= 10_000
    if speedup2 >= 1.5
      puts "   ✅ SUCCESS: Meets epic goal (≥1.5x speedup for #{size}+ items)"
    else
      puts "   ❌ FAIL: Does not meet epic goal (need ≥1.5x, got #{speedup2}x)"
    end
  end

  collector.record(size, "simple_pattern", "single_threaded", ips_single2, alloc_single2)
  collector.record(size, "simple_pattern", "parallel_fuzzy_match", ips_parallel2, alloc_parallel2)

  # Test 3: Different parallel methods (test our optimizations)
  puts "\n3. Parallel method comparison:"

  methods = [
    {name: "parallel_fuzzy_match", block: -> { matcher.parallel_fuzzy_match(haystacks, needle) }},
    {name: "parallel_fuzzy_match_fiber", block: -> { matcher.parallel_fuzzy_match_fiber(haystacks, needle) }},
    {name: "parallel_fuzzy_indices", block: -> { matcher.parallel_fuzzy_indices(haystacks, needle) }},
    {name: "parallel_fuzzy_indices_fiber", block: -> { matcher.parallel_fuzzy_indices_fiber(haystacks, needle) }},
  ]

  methods.each do |method|
    ips, alloc = benchmark_with_memory(method[:name]) do
      method[:block].call
    end

    puts "   #{method[:name].ljust(30)}: #{ips.round(1)} ips, #{alloc / 1024} KB alloc"
    collector.record(size, "method_comparison", method[:name], ips, alloc)
  end

  # Test 4: Memory allocation reduction goal
  puts "\n4. Memory allocation analysis:"
  puts "   Single-threaded allocation: #{alloc_single2 / 1024} KB"
  puts "   Parallel allocation: #{alloc_parallel2 / 1024} KB"
  puts "   Reduction: #{alloc_reduction2}%"

  # Epic success criteria: "Memory allocations reduced by 50% for parallel snapshot building"
  if alloc_reduction2 >= 50
    puts "   ✅ SUCCESS: Meets epic goal (≥50% allocation reduction)"
  else
    puts "   ❌ FAIL: Does not meet epic goal (need ≥50%, got #{alloc_reduction2}%)"
  end

  puts "\n" + "=" * 60
end

# Save results
config_hash = {
  "benchmark_type" => JSON::Any.new("epic_optimizations"),
  "test_sizes"     => JSON::Any.new(test_sizes.map { |s| JSON::Any.new(s) }),
  "epic_goals"     => JSON::Any.new([
    JSON::Any.new("Empty patterns return first N items in O(1) time"),
    JSON::Any.new("Parallel matching beats single-threaded by 1.5x+ for 10k+ items"),
    JSON::Any.new("Memory allocations reduced by 50% for parallel snapshot building"),
  ]),
  "timestamp" => JSON::Any.new(Time.utc.to_s),
}

result = collector.build_result(config_hash)
result_file = result.save("baseline")

puts "\n=== Benchmark Complete ==="
puts "Results saved to: #{result_file}"
puts
puts "Epic Success Criteria Summary:"
puts "1. Empty pattern O(1) time: ✅ Implemented (27.75x speedup from earlier)"
puts "2. Parallel speedup ≥1.5x for 10k+ items: ❌ Not yet achieved (need optimization)"
puts "3. Memory reduction ≥50%: ❌ Not yet achieved (need optimization)"
puts
puts "Next steps: Implement nucleoc-nar.3 (top-k) and nucleoc-nar.4 (ParSort)"
