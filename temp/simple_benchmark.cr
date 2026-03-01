require "../src/nucleoc"

# Simple benchmark to test current implementation
puts "Testing current parallel implementation..."

# Generate simple test data
words = ["file", "document", "test", "example", "code"]
test_data = Array.new(1000) do |i|
  "#{words[i % words.size]}_#{words[(i + 1) % words.size]}_#{i}.txt"
end

needle = "file"
matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)

# Warmup
puts "Warming up..."
3.times { matcher.parallel_fuzzy_match_fiber(test_data, needle) }

# Benchmark
puts "Benchmarking..."
iterations = 5
total_time = 0.0

iterations.times do |i|
  start_time = Time.instant
  results = matcher.parallel_fuzzy_match_fiber(test_data, needle)
  elapsed = (Time.instant - start_time).total_milliseconds
  total_time += elapsed

  valid_results = results.compact.size
  puts "  Run #{i + 1}: #{elapsed.round(2)}ms, matches: #{valid_results}/#{test_data.size}"
end

avg_time = total_time / iterations
throughput = (test_data.size / (avg_time / 1000)).to_i
puts "\nResults:"
puts "  Average time: #{avg_time.round(2)}ms"
puts "  Throughput: #{throughput} items/sec"
puts "  Dataset size: #{test_data.size} items"
