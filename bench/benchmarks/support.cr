require "benchmark"
require "random"
require "../../src/nucleoc"

module NucleocBench
  struct Config
    getter dataset_size : Int32
    getter haystack_size : Int32
    getter columns : Int32
    getter needle : String
    getter warmup : Time::Span
    getter calculation : Time::Span
    getter core_counts : Array(Int32)
    getter sort_sizes : Array(Int32)
    getter top_k : Int32

    def initialize(
      @dataset_size : Int32,
      @haystack_size : Int32,
      @columns : Int32,
      @needle : String,
      @warmup : Time::Span,
      @calculation : Time::Span,
      @core_counts : Array(Int32),
      @sort_sizes : Array(Int32),
      @top_k : Int32,
    )
    end
  end

  def self.config : Config
    @@config ||= Config.new(
      dataset_size: env_int("BENCH_DATASET", 10_000),
      haystack_size: env_int("BENCH_HAYSTACK", 64),
      columns: env_int("BENCH_COLUMNS", 3),
      needle: ENV["BENCH_NEEDLE"]? || "needle",
      warmup: env_seconds("BENCH_WARMUP", 2.0),
      calculation: env_seconds("BENCH_CALC", 5.0),
      core_counts: env_int_list("BENCH_CORES", [1, 2, 4]),
      sort_sizes: env_int_list("BENCH_SORT_SIZES", [1_000, 10_000, 100_000]),
      top_k: env_int("BENCH_TOPK", 100),
    )
  end

  def self.random_string(rng : Random, length : Int32) : String
    alphabet = "abcdefghijklmnopqrstuvwxyz"
    String.build(length) do |io|
      length.times do
        io << alphabet.byte_at(rng.rand(alphabet.bytesize)).chr
      end
    end
  end

  def self.random_string_with_needle(rng : Random, length : Int32, needle : String) : String
    return needle if length <= needle.bytesize
    remaining = length - needle.bytesize
    prefix_len = remaining // 2
    suffix_len = remaining - prefix_len
    "#{random_string(rng, prefix_len)}#{needle}#{random_string(rng, suffix_len)}"
  end

  def self.haystacks_with_needle(count : Int32, length : Int32, needle : String, seed : Int32) : Array(String)
    rng = Random.new(seed)
    Array.new(count) { random_string_with_needle(rng, length, needle) }
  end

  def self.multi_column_haystacks(count : Int32, columns : Int32, length : Int32, needle : String, seed : Int32) : Array(Array(String))
    rng = Random.new(seed)
    Array.new(count) do
      Array.new(columns) { random_string_with_needle(rng, length, needle) }
    end
  end

  def self.report_header(title : String, config : Config)
    puts "\n== #{title} =="
    puts "dataset=#{config.dataset_size} haystack=#{config.haystack_size} columns=#{config.columns}"
    puts "cores=#{config.core_counts.join(",")} sort_sizes=#{config.sort_sizes.join(",")}"
    puts "top_k=#{config.top_k}"
    puts "crystal_workers=#{ENV["CRYSTAL_WORKERS"]? || "default"}"
  end

  private def self.env_int(key : String, default_value : Int32) : Int32
    ENV[key]?.try(&.to_i?) || default_value
  end

  private def self.env_seconds(key : String, default_value : Float64) : Time::Span
    value = ENV[key]?.try(&.to_f?)
    value ? value.seconds : default_value.seconds
  end

  private def self.env_int_list(key : String, default_value : Array(Int32)) : Array(Int32)
    raw = ENV[key]?
    return default_value unless raw
    raw.split(',').map(&.strip).map(&.to_i)
  end
end
