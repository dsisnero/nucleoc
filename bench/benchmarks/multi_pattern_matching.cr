require "./support"

module NucleocBench
  module MultiPatternMatching
    def self.run(config : Config)
      report_header("MultiPattern concurrent matching", config)
      rows = multi_column_haystacks(
        config.dataset_size,
        config.columns,
        config.haystack_size,
        config.needle,
        9001
      )
      matcher = Nucleoc::Matcher.new
      pattern = Nucleoc::MultiPattern.new(config.columns)
      config.columns.times do |idx|
        pattern.reparse(idx, config.needle)
      end

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        x.report("multi_pattern score") do
          rows.each { |row| pattern.score(row, matcher) }
        end

        x.report("multi_pattern score_parallel") do
          rows.each { |row| pattern.score_parallel(row, Nucleoc::Config::DEFAULT) }
        end
      end
    end
  end
end
