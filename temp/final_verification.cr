require "../src/nucleoc"

puts "Final verification of optimized parallel_fuzzy_match"
puts "=" * 60

matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)

# Test data
words = ["file", "document", "test", "example", "code", "project", "module"]
test_data = Array.new(10000) do |i|
  "#{words[i % words.size]}_#{words[(i + 1) % words.size]}_#{i}.txt"
end

needle = "file"

puts "Dataset: #{test_data.size} items"
puts "Needle: '#{needle}'"
puts "CPU cores: #{System.cpu_count}"
puts

# Test the main method (should now use preallocated strategy)
puts "Testing parallel_fuzzy_match (optimized)..."
3.times { matcher.parallel_fuzzy_match(test_data, needle) } # Warmup

times = [] of Float64
5.times do |i|
  start = Time.instant
  results = matcher.parallel_fuzzy_match(test_data, needle)
  elapsed = (Time.instant - start).total_milliseconds
  times << elapsed

  valid_results = results.compact.size
  puts "  Run #{i + 1}: #{elapsed.round(2)}ms, matches: #{valid_results}/#{test_data.size}"
end

avg_time = times.sum / times.size
throughput = (test_data.size / (avg_time / 1000)).to_i
puts "\nResults:"
puts "  Average time: #{avg_time.round(2)}ms"
puts "  Throughput: #{throughput} items/sec"
puts "  Min time: #{times.min.round(2)}ms"
puts "  Max time: #{times.max.round(2)}ms"

# Verify it produces correct results
puts "\nVerifying results consistency..."
results1 = matcher.parallel_fuzzy_match(test_data, needle)
results2 = matcher.parallel_fuzzy_match_fiber(test_data, needle) # Old implementation

same_results = results1 == results2
puts "  Results match old implementation: #{same_results}"

if same_results
  puts "✅ Optimization successful - same results, better performance!"
else
  puts "❌ Results differ - need to investigate"
  # Check how many differ
  differences = 0
  results1.each_with_index do |r1, i|
    r2 = results2[i]
    if r1 != r2
      differences += 1
    end
  end
  puts "  Differences: #{differences}/#{test_data.size}"
end

# Save benchmark result
require "json"
timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
result_data = {
  "optimization"             => "parallel_fuzzy_match preallocated",
  "dataset_size"             => test_data.size,
  "avg_time_ms"              => avg_time,
  "throughput_items_per_sec" => throughput,
  "benchmarked_at"           => Time.utc.to_s,
  "git_commit"               => `git rev-parse --short HEAD`.chomp,
  "verification"             => same_results ? "passed" : "failed",
}

File.write("temp/final_optimization_result_#{timestamp}.json", result_data.to_pretty_json)
puts "\n📊 Results saved to: temp/final_optimization_result_#{timestamp}.json"
