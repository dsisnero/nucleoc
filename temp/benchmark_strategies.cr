require "../src/nucleoc"
require "json"

# Benchmarking system for parallel chunking strategies
module NucleocBench
  class StrategyBenchmark
    @strategies = {} of String => Proc(Array(String), String, Array(UInt16?))
    @results = {} of String => Hash(String, Float64)

    def initialize
      register_strategies
    end

    def register(name : String, &strategy : Array(String), String -> Array(UInt16?))
      @strategies[name] = strategy
    end

    private def register_strategies
      # Strategy 1: Current implementation (baseline)
      register("current_implementation") do |haystacks, needle|
        matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
        matcher.parallel_fuzzy_match_fiber(haystacks, needle)
      end

      # Strategy 2: Manual chunking without Array#each_slice
      register("manual_chunking") do |haystacks, needle|
        manual_chunking_strategy(haystacks, needle)
      end

      # Strategy 3: Single channel optimization
      register("single_channel") do |haystacks, needle|
        single_channel_strategy(haystacks, needle)
      end

      # Strategy 4: Pre-allocated arrays
      register("preallocated") do |haystacks, needle|
        preallocated_strategy(haystacks, needle)
      end
    end

    # Strategy 2: Manual chunking without Array#each_slice
    private def manual_chunking_strategy(haystacks : Array(String), needle : String) : Array(UInt16?)
      return [] of UInt16? if haystacks.empty?

      matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
      normalized_needle = matcher.normalize_needle(needle)

      cpu_count = System.cpu_count.to_i32
      target_chunks = cpu_count.clamp(1, 16)
      chunk_size = (haystacks.size // target_chunks).clamp(1, haystacks.size)

      channels = [] of Channel(Tuple(Int32, Array(UInt16?)))
      total_chunks = (haystacks.size + chunk_size - 1) // chunk_size

      total_chunks.times do |chunk_idx|
        chan = Channel(Tuple(Int32, Array(UInt16?))).new
        channels << chan
        start_idx = chunk_idx * chunk_size
        end_idx = Math.min(start_idx + chunk_size, haystacks.size)

        spawn do
          chunk_scores = Array(UInt16?).new(end_idx - start_idx, nil)
          (start_idx...end_idx).each do |i|
            chunk_scores[i - start_idx] = matcher.fuzzy_match_normalized(haystacks[i], normalized_needle)
          end
          chan.send({start_idx, chunk_scores})
        end
      end

      results = Array(UInt16?).new(haystacks.size, nil)
      channels.each do |chan|
        start_idx, chunk_scores = chan.receive
        chunk_scores.each_with_index do |score, idx|
          results[start_idx + idx] = score
        end
      end

      results
    end

    # Strategy 3: Single channel optimization
    private def single_channel_strategy(haystacks : Array(String), needle : String) : Array(UInt16?)
      return [] of UInt16? if haystacks.empty?

      matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
      normalized_needle = matcher.normalize_needle(needle)

      cpu_count = System.cpu_count.to_i32
      target_chunks = cpu_count.clamp(1, 16)
      chunk_size = (haystacks.size // target_chunks).clamp(1, haystacks.size)
      total_chunks = (haystacks.size + chunk_size - 1) // chunk_size

      # Single channel for all results
      result_channel = Channel(Tuple(Int32, Array(UInt16?))).new
      pending_chunks = total_chunks

      total_chunks.times do |chunk_idx|
        start_idx = chunk_idx * chunk_size
        end_idx = Math.min(start_idx + chunk_size, haystacks.size)

        spawn do
          chunk_scores = Array(UInt16?).new(end_idx - start_idx, nil)
          (start_idx...end_idx).each do |i|
            chunk_scores[i - start_idx] = matcher.fuzzy_match_normalized(haystacks[i], normalized_needle)
          end
          result_channel.send({start_idx, chunk_scores})
        end
      end

      results = Array(UInt16?).new(haystacks.size, nil)
      total_chunks.times do
        start_idx, chunk_scores = result_channel.receive
        chunk_scores.each_with_index do |score, idx|
          results[start_idx + idx] = score
        end
      end

      results
    end

    # Strategy 4: Pre-allocated arrays with reuse
    private def preallocated_strategy(haystacks : Array(String), needle : String) : Array(UInt16?)
      return [] of UInt16? if haystacks.empty?

      matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
      normalized_needle = matcher.normalize_needle(needle)

      cpu_count = System.cpu_count.to_i32
      target_chunks = cpu_count.clamp(1, 16)
      chunk_size = (haystacks.size // target_chunks).clamp(1, haystacks.size)
      total_chunks = (haystacks.size + chunk_size - 1) // chunk_size

      # Pre-allocate results array
      results = Array(UInt16?).new(haystacks.size, nil)
      completion_channel = Channel(Bool).new

      total_chunks.times do |chunk_idx|
        start_idx = chunk_idx * chunk_size
        end_idx = Math.min(start_idx + chunk_size, haystacks.size)

        spawn do
          (start_idx...end_idx).each do |i|
            results[i] = matcher.fuzzy_match_normalized(haystacks[i], normalized_needle)
          end
          completion_channel.send(true)
        end
      end

      # Wait for all chunks to complete
      total_chunks.times { completion_channel.receive }

      results
    end

    def run_benchmark(haystacks : Array(String), needle : String, iterations : Int32 = 10)
      puts "\n=== Benchmarking Parallel Chunking Strategies ==="
      puts "Dataset size: #{haystacks.size} items"
      puts "Needle: '#{needle}'"
      puts "Iterations: #{iterations}"
      puts "CPU cores: #{System.cpu_count}"
      puts "-" * 50

      @strategies.each do |name, strategy|
        puts "\nTesting: #{name}"

        # Warmup
        3.times { strategy.call(haystacks, needle) }

        # Benchmark
        total_time = 0.0
        iterations.times do |i|
          start_time = Time.instant
          results = strategy.call(haystacks, needle)
          elapsed = (Time.instant - start_time).total_milliseconds
          total_time += elapsed

          # Verify results are consistent
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
      end

      print_results
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

      # Save results to file
      save_results(sorted)
    end

    private def save_results(sorted_results)
      timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
      filename = "temp/benchmark_results_#{timestamp}.json"

      data = {
        "timestamp"       => Time.utc.to_s,
        "git_commit"      => `git rev-parse --short HEAD`.chomp,
        "crystal_version" => `crystal --version`.lines.first.chomp,
        "strategies"      => sorted_results.map do |name, metrics|
          {
            "name"                     => name,
            "avg_time_ms"              => metrics["avg_time_ms"],
            "throughput_items_per_sec" => metrics["throughput_items_per_sec"],
          }
        end,
      }

      File.write(filename, data.to_pretty_json)
      puts "Results saved to: #{filename}"

      # Update fastest strategy file
      fastest = sorted_results.first
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
end

# Generate test data
def generate_test_data(size : Int32) : Array(String)
  words = ["file", "document", "test", "example", "code", "project", "module", "class", "function", "method"]
  extensions = [".txt", ".pdf", ".doc", ".xls", ".py", ".rb", ".js", ".ts", ".java", ".c", ".cpp"]

  Array.new(size) do |i|
    word1 = words[Random.rand(words.size)]
    word2 = words[Random.rand(words.size)]
    ext = extensions[Random.rand(extensions.size)]
    "#{word1}_#{word2}_#{i}#{ext}"
  end
end

# Run benchmark
if __FILE__ == $0
  puts "Generating test data..."
  test_data = generate_test_data(10000)
  needle = "file"

  benchmark = NucleocBench::StrategyBenchmark.new
  benchmark.run_benchmark(test_data, needle, iterations: 5)
end
