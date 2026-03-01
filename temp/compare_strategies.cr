require "../src/nucleoc"
require "json"

# Benchmark comparison of different parallel strategies
class StrategyComparator
  @results = {} of String => Hash(String, Float64)

  def initialize
    @matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
  end

  def benchmark_strategy(name : String, haystacks : Array(String), needle : String, iterations : Int32 = 10, &block : Array(String), String -> Array(UInt16?))
    puts "Testing: #{name}"

    # Warmup
    3.times { block.call(haystacks, needle) }

    # Benchmark
    total_time = 0.0
    iterations.times do |i|
      start_time = Time.instant
      results = block.call(haystacks, needle)
      elapsed = (Time.instant - start_time).total_milliseconds
      total_time += elapsed

      if i == 0
        valid_results = results.compact.size
        puts "  Valid matches: #{valid_results}/#{haystacks.size}"
      end
    end

    avg_time = total_time / iterations
    throughput = (haystacks.size / (avg_time / 1000)).to_i
    @results[name] = {
      "avg_time_ms"              => avg_time,
      "throughput_items_per_sec" => throughput.to_f64,
    }

    puts "  Average time: #{avg_time.round(2)}ms"
    puts "  Throughput: #{throughput} items/sec"
    puts
  end

  def run_comparison(haystacks : Array(String), needle : String, iterations : Int32 = 10)
    puts "\n=== Comparing Parallel Strategies ==="
    puts "Dataset size: #{haystacks.size} items"
    puts "Needle: '#{needle}'"
    puts "Iterations: #{iterations}"
    puts "CPU cores: #{System.cpu_count}"
    puts "-" * 50

    # Test all strategies
    benchmark_strategy("sequential", haystacks, needle, iterations) do |h, n|
      normalized = @matcher.normalize_needle(n)
      h.map { |haystack| @matcher.fuzzy_match_normalized(haystack, normalized) }
    end

    benchmark_strategy("current_parallel", haystacks, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_fiber(h, n)
    end

    benchmark_strategy("optimized_manual_chunking", haystacks, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_optimized(h, n)
    end

    benchmark_strategy("preallocated_results", haystacks, needle, iterations) do |h, n|
      @matcher.parallel_fuzzy_match_preallocated(h, n)
    end

    print_results
    save_results
  end

  private def print_results
    puts "\n" + "=" * 60
    puts "RESULTS SUMMARY (sorted by throughput):"
    puts "=" * 60

    sorted = @results.to_a.sort_by { |_, metrics| -metrics["throughput_items_per_sec"] }

    sorted.each_with_index do |(name, metrics), idx|
      puts "#{idx + 1}. #{name}:"
      puts "   Time: #{metrics["avg_time_ms"].round(2)}ms"
      puts "   Throughput: #{metrics["throughput_items_per_sec"].to_i} items/sec"

      if idx == 0
        puts "   🏆 FASTEST STRATEGY"
      elsif idx > 0
        baseline = sorted[0][1]["throughput_items_per_sec"]
        current = metrics["throughput_items_per_sec"]
        percent_slower = ((baseline - current) / baseline * 100).round(1)
        puts "   #{percent_slower}% slower than fastest"
      end
      puts
    end
  end

  private def save_results
    timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
    filename = "temp/strategy_comparison_#{timestamp}.json"

    sorted = @results.to_a.sort_by { |_, metrics| -metrics["throughput_items_per_sec"] }

    data = {
      "timestamp"       => Time.utc.to_s,
      "git_commit"      => `git rev-parse --short HEAD`.chomp,
      "crystal_version" => `crystal --version`.lines.first.chomp,
      "strategies"      => sorted.map do |name, metrics|
        {
          "name"                     => name,
          "avg_time_ms"              => metrics["avg_time_ms"],
          "throughput_items_per_sec" => metrics["throughput_items_per_sec"],
        }
      end,
    }

    File.write(filename, data.to_pretty_json)
    puts "Results saved to: #{filename}"

    # Update fastest strategy
    fastest = sorted.first
    fastest_file = "temp/fastest_strategy.json"
    fastest_data = {
      "strategy"                 => fastest[0],
      "avg_time_ms"              => fastest[1]["avg_time_ms"],
      "throughput_items_per_sec" => fastest[1]["throughput_items_per_sec"],
      "benchmarked_at"           => Time.utc.to_s,
      "git_commit"               => `git rev-parse --short HEAD`.chomp,
    }

    File.write(fastest_file, fastest_data.to_pretty_json)
    puts "Fastest strategy saved to: #{fastest_file}"
  end
end

# Generate test data
def generate_test_data(size : Int32) : Array(String)
  words = ["file", "document", "test", "example", "code", "project", "module", "class", "function", "method"]
  extensions = [".txt", ".pdf", ".doc", ".xls", ".py", ".rb", ".js", ".ts", ".java", ".c", ".cpp"]

  random = Random.new
  Array.new(size) do |i|
    word1 = words[random.rand(words.size)]
    word2 = words[random.rand(words.size)]
    ext = extensions[random.rand(extensions.size)]
    "#{word1}_#{word2}_#{i}#{ext}"
  end
end

# Run comparison
if PROGRAM_NAME == __FILE__
  puts "Generating test data..."

  # Test different dataset sizes
  sizes = [1000, 5000, 10000]

  sizes.each do |size|
    puts "\n" + "=" * 70
    puts "DATASET SIZE: #{size} ITEMS"
    puts "=" * 70

    test_data = generate_test_data(size)
    needle = "file"

    comparator = StrategyComparator.new
    comparator.run_comparison(test_data, needle, iterations: 5)
  end
end
