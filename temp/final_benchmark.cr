require "../src/nucleoc"
require "json"

class FinalBenchmark
  def initialize
    @matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
    @all_results = [] of Hash(String, JSON::Any)
  end

  def benchmark_size(size : Int32, needle : String = "file", iterations : Int32 = 7)
    puts "\n" + "=" * 70
    puts "DATASET SIZE: #{size} ITEMS"
    puts "=" * 70

    # Generate test data
    words = ["file", "document", "test", "example", "code", "project", "module"]
    test_data = Array.new(size) do |i|
      "#{words[i % words.size]}_#{words[(i + 1) % words.size]}_#{i}.txt"
    end

    results = {} of String => Hash(String, Float64)

    # Test sequential (baseline)
    seq_time = benchmark("sequential", test_data, needle, iterations) do |h, n|
      normalized = @matcher.normalize_needle(n)
      h.map { |haystack| @matcher.fuzzy_match_normalized(haystack, normalized) }
    end
    results["sequential"] = seq_time

    # Test current implementation
    current_time = benchmark("current_parallel", test_data, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_fiber(h, n)
    end
    results["current_parallel"] = current_time

    # Test optimized
    optimized_time = benchmark("optimized", test_data, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_optimized(h, n)
    end
    results["optimized"] = optimized_time

    # Test preallocated
    prealloc_time = benchmark("preallocated", test_data, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_preallocated(h, n)
    end
    results["preallocated"] = prealloc_time

    print_results(results, size)
    save_size_results(results, size)

    results
  end

  private def benchmark(name : String, haystacks : Array(String), needle : String, iterations : Int32, &block : Array(String), String -> Array(UInt16?))
    puts "\nTesting: #{name}"

    # Warmup
    3.times { block.call(haystacks, needle) }

    # Benchmark
    times = [] of Float64
    iterations.times do |i|
      start_time = Time.instant
      results = block.call(haystacks, needle)
      elapsed = (Time.instant - start_time).total_milliseconds
      times << elapsed

      if i == 0
        valid_results = results.compact.size
        puts "  Matches: #{valid_results}/#{haystacks.size}"
      end
    end

    # Calculate statistics
    avg_time = times.sum / times.size
    min_time = times.min
    max_time = times.max
    stddev = Math.sqrt(times.sum { |t| (t - avg_time) ** 2 } / times.size)
    throughput = (haystacks.size / (avg_time / 1000)).to_i

    puts "  Time: #{avg_time.round(2)}ms (min: #{min_time.round(2)}ms, max: #{max_time.round(2)}ms, σ: #{stddev.round(2)}ms)"
    puts "  Throughput: #{throughput} items/sec"

    {
      "avg_time_ms"              => avg_time,
      "min_time_ms"              => min_time,
      "max_time_ms"              => max_time,
      "stddev_ms"                => stddev,
      "throughput_items_per_sec" => throughput.to_f64,
    }
  end

  private def print_results(results : Hash(String, Hash(String, Float64)), size : Int32)
    puts "\n" + "=" * 60
    puts "RESULTS SUMMARY for #{size} items (sorted by throughput):"
    puts "=" * 60

    sorted = results.to_a.sort_by { |_, metrics| -metrics["throughput_items_per_sec"] }

    sorted.each_with_index do |(name, metrics), idx|
      puts "#{idx + 1}. #{name}:"
      puts "   Time: #{metrics["avg_time_ms"].round(2)}ms (±#{metrics["stddev_ms"].round(2)}ms)"
      puts "   Throughput: #{metrics["throughput_items_per_sec"].to_i} items/sec"

      if idx == 0
        puts "   🏆 FASTEST"
        speedup_vs_seq = results["sequential"]["avg_time_ms"] / metrics["avg_time_ms"]
        puts "   Speedup vs sequential: #{speedup_vs_seq.round(2)}x"
      elsif name != "sequential"
        fastest = sorted[0][1]["throughput_items_per_sec"]
        current = metrics["throughput_items_per_sec"]
        percent_slower = ((fastest - current) / fastest * 100).round(1)
        puts "   #{percent_slower}% slower than fastest"
      end
      puts
    end
  end

  private def save_size_results(results : Hash(String, Hash(String, Float64)), size : Int32)
    sorted = results.to_a.sort_by { |_, metrics| -metrics["throughput_items_per_sec"] }

    size_result = {
      "dataset_size" => size,
      "timestamp"    => Time.utc.to_s,
      "strategies"   => sorted.map do |name, metrics|
        {
          "name"                     => name,
          "avg_time_ms"              => metrics["avg_time_ms"],
          "min_time_ms"              => metrics["min_time_ms"],
          "max_time_ms"              => metrics["max_time_ms"],
          "stddev_ms"                => metrics["stddev_ms"],
          "throughput_items_per_sec" => metrics["throughput_items_per_sec"],
        }
      end,
    }

    @all_results << JSON.parse(size_result.to_json).as_h
  end

  def save_all_results
    timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
    filename = "temp/benchmark_comprehensive_#{timestamp}.json"

    all_data = {
      "timestamp"       => Time.utc.to_s,
      "git_commit"      => `git rev-parse --short HEAD`.chomp,
      "crystal_version" => `crystal --version`.lines.first.chomp,
      "cpu_cores"       => System.cpu_count,
      "benchmarks"      => @all_results,
    }

    File.write(filename, all_data.to_pretty_json)
    puts "\n📊 All benchmark results saved to: #{filename}"

    # Determine overall fastest strategy
    fastest_by_size = {} of String => Int32
    @all_results.each do |result|
      fastest = result["strategies"].as_a.first["name"].as_s
      fastest_by_size[fastest] = fastest_by_size.fetch(fastest, 0) + 1
    end

    overall_fastest = fastest_by_size.max_by { |_, count| count }
    puts "🏆 Overall fastest strategy: #{overall_fastest[0]} (fastest in #{overall_fastest[1]}/#{@all_results.size} sizes)"

    # Save fastest strategy recommendation
    fastest_file = "temp/fastest_strategy_recommendation.json"
    fastest_data = {
      "recommended_strategy" => overall_fastest[0],
      "wins"                 => overall_fastest[1],
      "total_sizes"          => @all_results.size,
      "benchmarked_at"       => Time.utc.to_s,
      "git_commit"           => `git rev-parse --short HEAD`.chomp,
      "rationale"            => "Won in #{overall_fastest[1]} out of #{@all_results.size} dataset sizes",
    }

    File.write(fastest_file, fastest_data.to_pretty_json)
    puts "📋 Strategy recommendation saved to: #{fastest_file}"
  end
end

# Run comprehensive benchmark
if PROGRAM_NAME == __FILE__
  puts "🚀 COMPREHENSIVE PARALLEL STRATEGY BENCHMARK"
  puts "==========================================="

  benchmark = FinalBenchmark.new

  # Test different dataset sizes
  sizes = [1000, 5000, 10000, 20000]

  sizes.each do |size|
    benchmark.benchmark_size(size, "file", iterations: 5)
  end

  benchmark.save_all_results
  puts "\n✅ Benchmark complete!"
end
