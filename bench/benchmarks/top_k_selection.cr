require "./support"

module NucleocBench
  module TopKSelection
    def self.run(config : Config)
      NucleocBench.report_header("Top-K selection", config)
      rng = Random.new(5678)
      base_arrays = config.sort_sizes.map do |size|
        Array.new(size) { rng.rand(1_000_000) }
      end

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        base_arrays.each_with_index do |base, idx|
          size = config.sort_sizes[idx]
          x.report("sort_snapshot size=#{size}") do
            vector = Nucleoc::BoxcarVector(Int32).new
            base.each { |v| vector.push(v) }
            vector.sort_snapshot { |a, b| a < b }
          end

          x.report("top_k size=#{size} k=#{config.top_k}") do
            vector = Nucleoc::BoxcarVector(Int32).new
            base.each { |v| vector.push(v) }
            vector.top_k_snapshot(config.top_k) { |a, b| a < b }
          end
        end
      end
    end
  end
end
