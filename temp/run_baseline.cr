#!/usr/bin/env crystal
require "../src/nucleoc"
require "../bench/results/result_manager"

# Simple baseline benchmark runner
puts "=== Running Baseline Benchmark ==="
puts

# Generate test data
def generate_test_data(count : Int32) : Array(String)
  prefixes = ["src", "lib", "test"]
  words = ["controller", "model", "view", "service"]
  suffixes = [".cr", ".rb", ".js"]

  Array.new(count) do |i|
    prefix = prefixes[i % prefixes.size]
    word1 = words[i % words.size]
    word2 = words[(i * 7) % words.size]
    suffix = suffixes[i % suffixes.size]
    "#{prefix}/#{word1}_#{word2}#{suffix}"
  end
end

# Benchmark a method
def benchmark(method_name : String, &block : ->) : Float64
  # Warm up
  2.times { block.call }

  # Measure
  start_time = Time.monotonic
  iterations = 0
  duration = 500.milliseconds

  while (Time.monotonic - start_time) < duration
    block.call
    iterations += 1
  end

  elapsed = (Time.monotonic - start_time).total_seconds
  iterations_per_second = iterations / elapsed

  puts "  #{method_name.ljust(35)}: #{iterations_per_second.round(1)} iterations/sec"
  iterations_per_second
end

# Main benchmark
collector = NucleocBench::ResultCollector.new("parallel_matcher_baseline")

# Test sizes
test_sizes = [100, 1_000, 10_000]

test_sizes.each do |size|
  puts "\n=== Testing with #{size} items ==="

  haystacks = generate_test_data(size)
  matcher = Nucleoc::Matcher.new

  # Test patterns
  patterns = [
    {name: "empty", pattern: ""},
    {name: "simple", pattern: "test"},
    {name: "no_match", pattern: "xyz123"},
  ]

  patterns.each do |pattern_info|
    puts "\n  Pattern: #{pattern_info[:name]} (#{pattern_info[:pattern].inspect})"
    needle = pattern_info[:name]

    # Single-threaded baseline
    ips_single = benchmark("single-threaded") do
      normalized_needle = matcher.normalize_needle(needle)
      haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
    end

    collector.record(size, pattern_info[:name], "single_threaded", ips_single)

    # Parallel methods
    methods = [
      {name: "parallel_fuzzy_match", block: -> { matcher.parallel_fuzzy_match(haystacks, needle) }},
      {name: "parallel_fuzzy_match_fiber", block: -> { matcher.parallel_fuzzy_match_fiber(haystacks, needle) }},
      {name: "parallel_fuzzy_indices", block: -> { matcher.parallel_fuzzy_indices(haystacks, needle) }},
      {name: "parallel_fuzzy_indices_fiber", block: -> { matcher.parallel_fuzzy_indices_fiber(haystacks, needle) }},
    ]

    methods.each do |method|
      ips = benchmark(method[:name]) do
        method[:block].call
      end

      collector.record(size, pattern_info[:name], method[:name], ips)

      # Calculate speedup
      if ips_single > 0 && ips > 0
        speedup = (ips / ips_single).round(2)
        puts "    Speedup vs single-threaded: #{speedup}x"
      end
    end
  end
end

# Save results
config_hash = {
  "benchmark_type" => JSON::Any.new("parallel_matcher_baseline"),
  "test_sizes"     => JSON::Any.new(test_sizes.map { |s| JSON::Any.new(s) }),
  "timestamp"      => JSON::Any.new(Time.utc.to_s),
}

result = collector.build_result(config_hash)
result_file = result.save("baseline")

puts "\n=== Benchmark Complete ==="
puts "Results saved to: #{result_file}"
puts
puts "To compare future benchmarks:"
puts "  1. Make optimizations"
puts "  2. Run this benchmark again (it will save to 'current' directory)"
puts "  3. Run: crystal run bench/scripts/compare.cr --release all"
