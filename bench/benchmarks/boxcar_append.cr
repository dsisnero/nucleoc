require "./support"

module NucleocBench
  module BoxcarAppend
    def self.run(config : Config)
      NucleocBench.report_header("BoxcarVector append", config)
      values = Array.new(config.dataset_size) { |i| i }

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        x.report("boxcar push") do
          vector = Nucleoc::BoxcarVector(Int32).new
          values.each { |value| vector.push(value) }
        end

        x.report("boxcar push_all") do
          vector = Nucleoc::BoxcarVector(Int32).new
          vector.push_all(values)
        end
      end
    end
  end
end
