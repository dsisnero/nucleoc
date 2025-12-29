require "./support"

module NucleocBench
  module WorkerPoolThroughput
    def self.run(config : Config)
      NucleocBench.report_header("Worker pool throughput", config)
      haystacks = NucleocBench.haystacks_with_needle(
        config.dataset_size,
        config.haystack_size,
        config.needle,
        4242
      )
      matcher = Nucleoc::Matcher.new
      cml_pools = config.core_counts.map { |workers| {workers, Nucleoc::CMLWorkerPool.new(workers)} }
      fiber_pools = config.core_counts.map { |workers| {workers, Nucleoc::FiberWorkerPool.new(workers)} }

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        x.report("sequential matcher") do
          haystacks.each { |haystack| matcher.fuzzy_match(haystack, config.needle) }
        end

        x.report("spawn parallel matcher") do
          matcher.parallel_fuzzy_match(haystacks, config.needle)
        end

        x.report("fiber parallel matcher") do
          matcher.parallel_fuzzy_match_fiber(haystacks, config.needle)
        end

        fiber_pools.each do |workers, pool|
          x.report("fiber_pool workers=#{workers}") do
            pool.match_many(haystacks, config.needle, false)
          end
        end

        cml_pools.each do |workers, pool|
          x.report("cml_pool workers=#{workers}") do
            pool.match_many(haystacks, config.needle, false)
          end
        end
      end
    end
  end
end
