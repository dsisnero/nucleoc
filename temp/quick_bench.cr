require "../src/nucleoc"

puts "Quick benchmark of parallel strategies..."
puts "=" * 50

matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)

# Generate test data
words = ["file", "document", "test", "example", "code"]
sizes = [1000, 5000, 10000]

sizes.each do |size|
  puts "\n📊 Dataset size: #{size} items"
  puts "-" * 30

  test_data = Array.new(size) do |i|
    "#{words[i % words.size]}_#{words[(i + 1) % words.size]}_#{i}.txt"
  end

  needle = "file"

  # Test each strategy
  strategies = {
    "Current"      => -> { matcher.parallel_fuzzy_match_fiber(test_data, needle) },
    "Optimized"    => -> { matcher.parallel_fuzzy_match_optimized(test_data, needle) },
    "Preallocated" => -> { matcher.parallel_fuzzy_match_preallocated(test_data, needle) },
  }

  results = {} of String => Float64

  strategies.each do |name, strategy|
    # Warmup
    3.times { strategy.call }

    # Benchmark
    times = [] of Float64
    5.times do
      start = Time.instant
      strategy.call
      elapsed = (Time.instant - start).total_milliseconds
      times << elapsed
    end

    avg_time = times.sum / times.size
    throughput = (size / (avg_time / 1000)).to_i
    results[name] = avg_time

    puts "#{name}:"
    puts "  Time: #{avg_time.round(2)}ms"
    puts "  Throughput: #{throughput} items/sec"
  end

  # Find fastest
  fastest = results.min_by { |_, time| time }
  puts "\n🏆 Fastest: #{fastest[0]} (#{fastest[1].round(2)}ms)"

  # Calculate speedup vs current
  current_time = results["Current"]
  if fastest[0] != "Current"
    speedup = current_time / fastest[1]
    puts "  Speedup vs Current: #{speedup.round(2)}x"
  end
end

puts "\n✅ Benchmark complete!"
