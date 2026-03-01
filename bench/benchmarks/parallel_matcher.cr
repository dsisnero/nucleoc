require "./support"
require "../results/result_manager"

module NucleocBench
  module ParallelMatcher
    # Generate realistic test data (filenames, code identifiers, etc.)
    def self.generate_test_data(count : Int32, seed : Int32 = 4242) : Array(String)
      rng = Random.new(seed)

      # Common words and patterns for realistic test data
      prefixes = ["src", "lib", "test", "spec", "docs", "config", "build", "dist", "public", "private"]
      words = [
        "controller", "model", "view", "service", "helper", "util", "config", "settings",
        "database", "schema", "migration", "query", "router", "middleware", "handler",
        "component", "module", "package", "dependency", "library", "framework",
        "interface", "implementation", "abstract", "concrete", "factory", "builder",
        "adapter", "decorator", "proxy", "facade", "singleton", "observer", "strategy",
      ]
      suffixes = [".cr", ".rb", ".js", ".ts", ".py", ".java", ".go", ".rs", ".cpp", ".h"]

      Array.new(count) do |i|
        prefix = prefixes[i % prefixes.size]
        word1 = words[i % words.size]
        word2 = words[(i * 7) % words.size]
        suffix = suffixes[i % suffixes.size]

        # Vary the patterns
        case rng.rand(4)
        when 0
          "#{prefix}/#{word1}_#{word2}#{suffix}"
        when 1
          "#{prefix}/#{word1}/#{word2}#{suffix}"
        when 2
          "#{word1.camelcase}#{word2.camelcase}#{suffix}"
        else
          "#{word1}_#{word2}_#{i}#{suffix}"
        end
      end
    end

    # Run benchmarks for different dataset sizes
    def self.run(config : Config)
      NucleocBench.report_header("Parallel Matcher Performance", config)

      # Test different dataset sizes
      test_sizes = [100, 1_000, 10_000, 50_000, 100_000]

      test_sizes.each do |size|
        puts "\n=== Testing with #{size} items ==="

        # Generate test data
        haystacks = generate_test_data(size)

        # Test different pattern types
        patterns = [
          {name: "empty", pattern: ""},
          {name: "simple", pattern: "test"},
          {name: "camel_case", pattern: "ControllerModel"},
          {name: "multi_word", pattern: "controller_model"},
          {name: "no_match", pattern: "xyz123abc"},
        ]

        patterns.each do |pattern_info|
          puts "\n  Pattern: #{pattern_info[:name]} (#{pattern_info[:pattern].inspect})"

          matcher = Nucleoc::Matcher.new
          needle = pattern_info[:pattern]

          # Warm up
          if size <= 1000
            matcher.parallel_fuzzy_match(haystacks[0..99], needle) if size >= 100
          end

          # Benchmark different methods
          Benchmark.ips(warmup: config.warmup, calculation: config.calculation) do |x|
            # Single-threaded baseline
            x.report("single-threaded") do
              normalized_needle = matcher.normalize_needle(needle)
              haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
            end

            # Parallel methods
            x.report("parallel_fuzzy_match") do
              matcher.parallel_fuzzy_match(haystacks, needle)
            end

            x.report("parallel_fuzzy_match_fiber") do
              matcher.parallel_fuzzy_match_fiber(haystacks, needle)
            end

            x.report("parallel_fuzzy_indices") do
              matcher.parallel_fuzzy_indices(haystacks, needle)
            end

            x.report("parallel_fuzzy_indices_fiber") do
              matcher.parallel_fuzzy_indices_fiber(haystacks, needle)
            end
          end
        end
      end
    end

    # Memory allocation benchmark
    def self.run_memory_benchmark(config : Config)
      NucleocBench.report_header("Parallel Matcher Memory Usage", config)

      puts "\n=== Memory Allocation Test ==="

      # Use medium dataset for memory test
      size = 10_000
      haystacks = generate_test_data(size)
      matcher = Nucleoc::Matcher.new
      needle = "controller"

      # Track memory usage
      GC.collect
      initial_memory = GC.stats.total_bytes

      puts "  Testing with #{size} items, pattern: #{needle}"
      puts "  Initial memory: #{initial_memory / 1024} KB"

      # Test each method and track memory
      methods = [
        {name: "single-threaded", block: -> {
          normalized_needle = matcher.normalize_needle(needle)
          haystacks.map { |haystack| matcher.fuzzy_match_normalized(haystack, normalized_needle) }
        }},
        {name: "parallel_fuzzy_match", block: -> { matcher.parallel_fuzzy_match(haystacks, needle) }},
        {name: "parallel_fuzzy_indices", block: -> { matcher.parallel_fuzzy_indices(haystacks, needle) }},
      ]

      methods.each do |method|
        GC.collect
        start_memory = GC.stats.total_bytes

        # Run method multiple times
        10.times { method[:block].call }

        GC.collect
        end_memory = GC.stats.total_bytes
        allocated = end_memory - start_memory

        puts "  #{method[:name].ljust(25)}: #{allocated / 1024} KB allocated"
      end
    end

    # Chunk size sensitivity analysis
    def self.run_chunk_size_analysis(config : Config)
      NucleocBench.report_header("Chunk Size Sensitivity Analysis", config)

      puts "\n=== Testing Different Chunk Sizes ==="

      size = 50_000
      haystacks = generate_test_data(size)
      matcher = Nucleoc::Matcher.new
      needle = "test"

      # Test different chunk sizes
      chunk_sizes = [10, 50, 100, 500, 1000, 5000]

      chunk_sizes.each do |chunk_size|
        puts "\n  Chunk size: #{chunk_size}"

        Benchmark.ips(warmup: 1.second, calculation: 3.seconds) do |x|
          x.report("parallel_fuzzy_match") do
            matcher.parallel_fuzzy_match(haystacks, needle, chunk_size)
          end
        end
      end
    end
  end
end
