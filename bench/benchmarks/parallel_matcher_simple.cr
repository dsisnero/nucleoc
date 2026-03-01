require "./support"
require "../results/result_manager"

module NucleocBench
  module ParallelMatcherSimple
    # Generate realistic test data
    def self.generate_test_data(count : Int32, seed : Int32 = 4242) : Array(String)
      rng = Random.new(seed)

      prefixes = ["src", "lib", "test", "spec", "docs"]
      words = ["controller", "model", "view", "service", "helper", "util"]
      suffixes = [".cr", ".rb", ".js", ".ts", ".py"]

      Array.new(count) do |i|
        prefix = prefixes[i % prefixes.size]
        word1 = words[i % words.size]
        word2 = words[(i * 7) % words.size]
        suffix = suffixes[i % suffixes.size]
        "#{prefix}/#{word1}_#{word2}#{suffix}"
      end
    end

    # Run benchmark and collect results
    def self.run(config : Config)
      puts "Running Parallel Matcher Benchmark (simple version)..."

      collector = ResultCollector.new("parallel_matcher")

      # Test smaller dataset sizes for quick benchmarking
      test_sizes = [100, 1_000, 10_000]

      test_sizes.each do |size|
        puts "\nTesting with #{size} items"

        # Generate test data
        haystacks = generate_test_data(size)

        # Test different pattern types
        patterns = [
          {name: "empty", pattern: ""},
          {name: "simple", pattern: "test"},
          {name: "no_match", pattern: "xyz123abc"},
        ]

        patterns.each do |pattern_info|
          puts "  Pattern: #{pattern_info[:name]}"

          matcher = Nucleoc::Matcher.new
          needle = pattern_info[:pattern]

          # Benchmark single-threaded
          ips_single = benchmark_method("single-threaded") do
            normalized_needle = matcher.normalize_needle(needle)
            haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
          end

          collector.record(size, pattern_info[:name], "single_threaded", ips_single)

          # Benchmark parallel methods
          methods = [
            {name: "parallel_fuzzy_match", block: -> { matcher.parallel_fuzzy_match(haystacks, needle) }},
            {name: "parallel_fuzzy_match_fiber", block: -> { matcher.parallel_fuzzy_match_fiber(haystacks, needle) }},
            {name: "parallel_fuzzy_indices", block: -> { matcher.parallel_fuzzy_indices(haystacks, needle) }},
            {name: "parallel_fuzzy_indices_fiber", block: -> { matcher.parallel_fuzzy_indices_fiber(haystacks, needle) }},
          ]

          methods.each do |method|
            ips = benchmark_method(method[:name]) do
              method[:block].call
            end

            collector.record(size, pattern_info[:name], method[:name], ips)

            # Calculate speedup vs single-threaded
            if ips_single > 0 && ips > 0
              speedup = (ips / ips_single).round(2)
              puts "    #{method[:name].ljust(30)}: #{ips.round(1)} ips (speedup: #{speedup}x)"
            end
          end
        end
      end

      # Build and save result
      config_hash = {
        "dataset_sizes"   => JSON::Any.new(test_sizes),
        "tested_patterns" => JSON::Any.new(patterns.map { |p| p[:name] }),
        "tested_methods"  => JSON::Any.new(["single_threaded", "parallel_fuzzy_match", "parallel_fuzzy_match_fiber",
                                           "parallel_fuzzy_indices", "parallel_fuzzy_indices_fiber"]),
      }

      result = collector.build_result(config_hash)
      result_file = result.save

      puts "\nBenchmark results saved to: #{result_file}"
    end

    # Simple benchmarking helper
    private def self.benchmark_method(name : String, &block : -> T) : Float64 forall T
      # Warm up
      3.times { block.call }

      # Measure
      start_time = Time.monotonic
      iterations = 0
      duration = 200.milliseconds # Short duration for quick benchmarking

      while (Time.monotonic - start_time) < duration
        block.call
        iterations += 1
      end

      elapsed = (Time.monotonic - start_time).total_seconds
      iterations_per_second = iterations / elapsed

      iterations_per_second
    end
  end
end
