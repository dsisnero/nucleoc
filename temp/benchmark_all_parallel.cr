require "../src/nucleoc"

# Generate test data
def generate_test_data(count : Int32) : Array(String)
  words = [
    "hello", "world", "test", "example", "benchmark", "performance", "optimization",
    "crystal", "language", "programming", "computer", "science", "algorithm",
    "data", "structure", "function", "method", "class", "object", "variable",
    "constant", "type", "interface", "implementation", "compilation", "execution",
    "runtime", "memory", "allocation", "garbage", "collection", "concurrency",
    "parallelism", "thread", "fiber", "channel", "synchronization", "mutex",
    "semaphore", "deadlock", "race", "condition", "performance", "benchmark",
    "measurement", "profiling", "optimization", "improvement", "enhancement",
  ]

  Array.new(count) do |i|
    # Mix words to create varied test strings
    word1 = words[i % words.size]
    word2 = words[(i * 7) % words.size]
    word3 = words[(i * 13) % words.size]
    "#{word1}_#{word2}_#{word3}_#{i}"
  end
end

# Benchmark a single method
def benchmark_method(name : String, &block : -> T) : {Float64, T} forall T
  GC.collect
  start_time = Time.monotonic
  result = block.call
  end_time = Time.monotonic
  elapsed_ms = (end_time - start_time).total_milliseconds
  {elapsed_ms, result}
end

# Verify results match
def verify_results(results1 : Array(T?), results2 : Array(T?)) : Bool forall T
  return false if results1.size != results2.size

  results1.each_with_index do |r1, i|
    r2 = results2[i]

    if r1.nil? && r2.nil?
      next
    elsif r1.nil? || r2.nil?
      return false
    elsif r1 != r2
      return false
    end
  end

  true
end

# Main benchmark
puts "=== Comprehensive Parallel Methods Benchmark ==="
puts

matcher = Nucleoc::Matcher.new
needle = "test"

# Test different sizes
test_sizes = [10, 100, 1000, 5000]

test_sizes.each do |size|
  puts "Testing with #{size} items:"
  puts "-" * 50

  haystacks = generate_test_data(size)

  # Benchmark all parallel methods
  methods = [
    {
      name:  "parallel_fuzzy_match",
      block: -> { matcher.parallel_fuzzy_match(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_match_fiber",
      block: -> { matcher.parallel_fuzzy_match_fiber(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_indices",
      block: -> { matcher.parallel_fuzzy_indices(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_indices_fiber",
      block: -> { matcher.parallel_fuzzy_indices_fiber(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_match_preallocated",
      block: -> { matcher.parallel_fuzzy_match_preallocated(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_indices_preallocated",
      block: -> { matcher.parallel_fuzzy_indices_preallocated(haystacks, needle) },
    },
    {
      name:  "parallel_fuzzy_indices_fiber_preallocated",
      block: -> { matcher.parallel_fuzzy_indices_fiber_preallocated(haystacks, needle) },
    },
  ]

  # Run each method 3 times and take average
  results = {} of String => Tuple(Float64, Array(UInt16?))

  methods.each do |method|
    times = [] of Float64
    method_result = nil

    3.times do |run|
      elapsed_ms, result = benchmark_method("#{method[:name]}_run#{run}") do
        method[:block].call
      end
      times << elapsed_ms
      method_result = result if run == 0
    end

    avg_time = times.sum / times.size
    results[method[:name]] = {avg_time, method_result.as(Array(UInt16?))}
  end

  # Print results
  results.each do |name, (time, _)|
    puts "  #{name.ljust(45)}: #{time.round(2)}ms"
  end

  # Verify consistency
  puts "\n  Verifying result consistency:"

  # Get baseline result
  baseline_result = results["parallel_fuzzy_match"][1]

  # Check each method against baseline
  results.each do |name, (_, result)|
    matches = verify_results(baseline_result, result)
    status = matches ? "✓" : "✗"
    puts "    #{status} #{name}"
  end

  puts
end

# Test empty pattern optimization
puts "=== Testing Empty Pattern Optimization ==="
puts

empty_needle = ""
test_size = 5000
haystacks = generate_test_data(test_size)

puts "Testing with empty needle and #{test_size} items:"

# Test regular match (should use fast path)
start_time = Time.monotonic
results1 = matcher.parallel_fuzzy_match(haystacks, empty_needle)
end_time = Time.monotonic
time1 = (end_time - start_time).total_milliseconds

# Test indices match (should use fast path)
start_time = Time.monotonic
results2 = matcher.parallel_fuzzy_indices(haystacks, empty_needle)
end_time = Time.monotonic
time2 = (end_time - start_time).total_milliseconds

puts "  parallel_fuzzy_match (empty): #{time1.round(2)}ms"
puts "  parallel_fuzzy_indices (empty): #{time2.round(2)}ms"

# Verify all scores are 0 for empty pattern
all_zero1 = results1.all? { |r| r == 0_u16 }
all_zero2 = results2.all? { |r| r && r[0] == 0_u16 }

puts "  All scores zero? parallel_fuzzy_match: #{all_zero1 ? '✓' : '✗'}"
puts "  All scores zero? parallel_fuzzy_indices: #{all_zero2 ? '✓' : '✗'}"
puts

# Test with non-empty pattern for comparison
puts "Testing with non-empty pattern for comparison:"
needle = "test"

start_time = Time.monotonic
results3 = matcher.parallel_fuzzy_match(haystacks, needle)
end_time = Time.monotonic
time3 = (end_time - start_time).total_milliseconds

start_time = Time.monotonic
results4 = matcher.parallel_fuzzy_indices(haystacks, needle)
end_time = Time.monotonic
time4 = (end_time - start_time).total_milliseconds

puts "  parallel_fuzzy_match (non-empty): #{time3.round(2)}ms"
puts "  parallel_fuzzy_indices (non-empty): #{time4.round(2)}ms"

speedup1 = time3 > 0 ? time3 / time1 : 0
speedup2 = time4 > 0 ? time4 / time2 : 0

puts "  Empty pattern speedup (match): #{speedup1.round(2)}x"
puts "  Empty pattern speedup (indices): #{speedup2.round(2)}x"
puts

puts "=== Benchmark Complete ==="
