require "../benchmarks/support"
require "../benchmarks/boxcar_append"
require "../benchmarks/par_sort_scaling"
require "../benchmarks/worker_pool_throughput"
require "../benchmarks/multi_pattern_matching"
require "../benchmarks/top_k_selection"

module NucleocBench
  BENCHMARKS = {
    "boxcar"        => BoxcarAppend,
    "par_sort"      => ParSortScaling,
    "worker_pool"   => WorkerPoolThroughput,
    "multi_pattern" => MultiPatternMatching,
    "top_k"         => TopKSelection,
  }

  def self.run_all(config : Config)
    BENCHMARKS.each_value do |benchmark|
      benchmark.run(config)
    end
  end

  def self.run_selected(config : Config, selections : Array(String))
    selections.each do |name|
      benchmark = BENCHMARKS[name]?
      if benchmark
        benchmark.run(config)
      else
        STDERR.puts "Unknown benchmark: #{name}"
      end
    end
  end

  def self.print_help
    puts "Usage: crystal run bench/src/main.cr --release -- [benchmarks...]"
    keys = BENCHMARKS.keys
    keys.sort!
    puts "Available benchmarks: #{keys.join(", ")}, all"
    puts "Environment variables:"
    puts "  BENCH_DATASET     Number of rows (default 10000)"
    puts "  BENCH_HAYSTACK    Haystack length (default 64)"
    puts "  BENCH_NEEDLE      Needle string (default \"needle\")"
    puts "  BENCH_COLUMNS     MultiPattern columns (default 3)"
    puts "  BENCH_CORES       Worker counts, comma-separated (default 1,2,4)"
    puts "  BENCH_SORT_SIZES  ParSort sizes, comma-separated (default 1000,10000,100000)"
    puts "  BENCH_TOPK        Top-K selection size (default 100)"
    puts "  BENCH_WARMUP      Warmup seconds (default 2.0)"
    puts "  BENCH_CALC        Calculation seconds (default 5.0)"
    puts "  CRYSTAL_WORKERS   Thread count for CML.spawn scaling"
  end
end

if ARGV.includes?("--help") || ARGV.includes?("-h")
  NucleocBench.print_help
  exit
end

config = NucleocBench.config
selections = ARGV.reject(&.starts_with?('-'))

if selections.empty? || selections.includes?("all")
  NucleocBench.run_all(config)
else
  NucleocBench.run_selected(config, selections)
end
