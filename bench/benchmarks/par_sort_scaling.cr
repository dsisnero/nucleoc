require "./support"

module NucleocBench
  module ParSortScaling
    def self.run(config : Config)
      NucleocBench.report_header("ParSort scaling", config)
      rng = Random.new(1234)
      base_arrays = config.sort_sizes.map do |size|
        Array.new(size) { rng.rand(1_000_000) }
      end

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        base_arrays.each_with_index do |base, idx|
          size = config.sort_sizes[idx]
          x.report("par_sort size=#{size}") do
            values = base.dup
            canceled = Atomic(Bool).new(false)
            Nucleoc::ParSort.par_quicksort(values, canceled) { |a, b| a < b }
          end
        end
      end
    end
  end
end
