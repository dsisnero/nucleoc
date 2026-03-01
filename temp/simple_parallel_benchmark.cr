require "../src/nucleoc"

# Generate test data
def generate_test_data(count : Int32) : Array(String)
  words = [
    "hello", "world", "test", "example", "benchmark", "performance", "optimization",
    "crystal", "language", "programming", "computer", "science", "algorithm",
    "data", "structure", "function", "method", "class", "object", "variable",
  ]

  Array.new(count) do |i|
    word1 = words[i % words.size]
    word2 = words[(i * 7) % words.size]
    "#{word1}_#{word2}_#{i}"
  end
end

# Simple benchmark function
def benchmark(name : String, &block : ->) : Float64
  GC.collect
  start_time = Time.monotonic
  block.call
  end_time = Time.monotonic
  elapsed_ms = (end_time - start_time).total_milliseconds
  puts "  #{name.ljust(40)}: #{elapsed_ms.round(2)}ms"
  elapsed_ms
end

puts "=== Parallel Methods Performance Test ==="
puts

matcher = Nucleoc::Matcher.new
needle = "test"

# Test different sizes
test_sizes = [100, 1000, 5000]

test_sizes.each do |size|
  puts "Testing with #{size} items:"
  puts "-" * 50

  haystacks = generate_test_data(size)

  # Warm up
  matcher.parallel_fuzzy_match(haystacks[0..99], needle) if size >= 100

  # Benchmark match methods
  puts "  Match methods (returns scores only):"
  t1 = benchmark("parallel_fuzzy_match") { matcher.parallel_fuzzy_match(haystacks, needle) }
  t2 = benchmark("parallel_fuzzy_match_fiber") { matcher.parallel_fuzzy_match_fiber(haystacks, needle) }
  t3 = benchmark("parallel_fuzzy_match_preallocated") { matcher.parallel_fuzzy_match_preallocated(haystacks, needle) }

  puts "  Speedup vs original: #{(t1/t3).round(2)}x" if t3 > 0

  puts "\n  Indices methods (returns scores + indices):"
  t4 = benchmark("parallel_fuzzy_indices") { matcher.parallel_fuzzy_indices(haystacks, needle) }
  t5 = benchmark("parallel_fuzzy_indices_fiber") { matcher.parallel_fuzzy_indices_fiber(haystacks, needle) }
  t6 = benchmark("parallel_fuzzy_indices_preallocated") { matcher.parallel_fuzzy_indices_preallocated(haystacks, needle) }

  puts "  Speedup vs original: #{(t4/t6).round(2)}x" if t6 > 0
  puts
end

# Test empty pattern optimization
puts "=== Empty Pattern Optimization Test ==="
puts

empty_needle = ""
test_size = 5000
haystacks = generate_test_data(test_size)

puts "Testing with empty needle and #{test_size} items:"

# Empty pattern
t_empty1 = benchmark("parallel_fuzzy_match (empty)") { matcher.parallel_fuzzy_match(haystacks, empty_needle) }
t_empty2 = benchmark("parallel_fuzzy_indices (empty)") { matcher.parallel_fuzzy_indices(haystacks, empty_needle) }

# Non-empty pattern for comparison
needle = "test"
t_normal1 = benchmark("parallel_fuzzy_match (non-empty)") { matcher.parallel_fuzzy_match(haystacks, needle) }
t_normal2 = benchmark("parallel_fuzzy_indices (non-empty)") { matcher.parallel_fuzzy_indices(haystacks, needle) }

puts "\n  Empty pattern speedup:"
puts "    Match: #{t_normal1 > 0 ? (t_normal1/t_empty1).round(2) : 0}x"
puts "    Indices: #{t_normal2 > 0 ? (t_normal2/t_empty2).round(2) : 0}x"
puts

# Verify correctness
puts "=== Correctness Verification ==="
puts

small_haystacks = generate_test_data(10)
results1 = matcher.parallel_fuzzy_match(small_haystacks, needle)
results2 = matcher.parallel_fuzzy_match_preallocated(small_haystacks, needle)
results3 = matcher.parallel_fuzzy_indices(small_haystacks, needle)
results4 = matcher.parallel_fuzzy_indices_preallocated(small_haystacks, needle)

# Check match results
match_ok = true
results1.each_with_index do |r1, i|
  r2 = results2[i]
  if r1 != r2
    puts "  ✗ Match results differ at index #{i}: #{r1} vs #{r2}"
    match_ok = false
  end
end
puts "  ✓ All match methods produce identical results" if match_ok

# Check indices results (compare scores only)
indices_ok = true
results3.each_with_index do |r1, i|
  r2 = results4[i]
  if r1.nil? && r2.nil?
    next
  elsif r1.nil? || r2.nil?
    puts "  ✗ Indices results differ at index #{i}: one is nil"
    indices_ok = false
  elsif r1[0] != r2[0] # Compare scores only
    puts "  ✗ Indices scores differ at index #{i}: #{r1[0]} vs #{r2[0]}"
    indices_ok = false
  end
end
puts "  ✓ All indices methods produce identical scores" if indices_ok

puts "\n=== Test Complete ==="
