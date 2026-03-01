require "json"
require "time"

module NucleocBench
  # Benchmark result data structure
  struct BenchmarkResult
    include JSON::Serializable

    property timestamp : Time
    property git_commit : String
    property git_branch : String
    property benchmark_name : String
    property config : Hash(String, JSON::Any)
    property results : Hash(String, Hash(String, Hash(String, JSON::Any)))

    def initialize(
      @benchmark_name : String,
      @config : Hash(String, JSON::Any),
      @results : Hash(String, Hash(String, Hash(String, JSON::Any))),
    )
      @timestamp = Time.utc
      @git_commit = get_git_commit
      @git_branch = get_git_branch
    end

    private def get_git_commit : String
      `git rev-parse --short HEAD`.strip
    rescue
      "unknown"
    end

    private def get_git_branch : String
      `git rev-parse --abbrev-ref HEAD`.strip
    rescue
      "unknown"
    end

    # Save result to file
    def save(directory : String = "current")
      dir_path = File.join("bench", "results", directory)
      Dir.mkdir_p(dir_path)

      filename = "#{@benchmark_name}_#{@timestamp.to_s("%Y%m%d_%H%M%S")}.json"
      filepath = File.join(dir_path, filename)

      File.write(filepath, self.to_pretty_json)
      filepath
    end

    # Load result from file
    def self.load(filepath : String) : BenchmarkResult
      content = File.read(filepath)
      BenchmarkResult.from_json(content)
    end

    # Compare with another result
    def compare(other : BenchmarkResult) : ComparisonResult
      ComparisonResult.new(self, other)
    end
  end

  # Comparison result
  struct ComparisonResult
    property baseline : BenchmarkResult
    property current : BenchmarkResult
    property differences : Array(Difference)

    struct Difference
      property test_case : String
      property metric : String
      property baseline_value : Float64
      property current_value : Float64
      property change_percent : Float64
      property improvement : Bool

      def initialize(@test_case, @metric, @baseline_value, @current_value)
        @change_percent = calculate_change_percent
        @improvement = @change_percent > 0
      end

      private def calculate_change_percent : Float64
        return 0.0 if @baseline_value == 0
        ((@current_value - @baseline_value) / @baseline_value.abs) * 100.0
      end
    end

    def initialize(@baseline, @current)
      @differences = calculate_differences
    end

    private def calculate_differences : Array(Difference)
      diffs = [] of Difference

      # Compare results structure
      @baseline.results.each do |dataset_size, dataset_results|
        current_dataset = @current.results[dataset_size]?
        next unless current_dataset

        dataset_results.each do |pattern_type, pattern_results|
          current_pattern = current_dataset[pattern_type]?
          next unless current_pattern

          pattern_results.each do |method_name, method_results|
            current_method = current_pattern[method_name]?
            next unless current_method

            # Compare iterations per second
            baseline_ips = method_results["iterations_per_second"]?.try(&.as_f?) || 0.0
            current_ips = current_method["iterations_per_second"]?.try(&.as_f?) || 0.0

            if baseline_ips != 0 || current_ips != 0
              diffs << Difference.new(
                "#{dataset_size}/#{pattern_type}/#{method_name}",
                "iterations_per_second",
                baseline_ips,
                current_ips
              )
            end

            # Compare allocation bytes
            baseline_alloc = method_results["allocation_bytes"]?.try(&.as_f?) || 0.0
            current_alloc = current_method["allocation_bytes"]?.try(&.as_f?) || 0.0

            if baseline_alloc != 0 || current_alloc != 0
              # For allocations, lower is better (negative change is improvement)
              diffs << Difference.new(
                "#{dataset_size}/#{pattern_type}/#{method_name}",
                "allocation_bytes",
                baseline_alloc,
                current_alloc
              )
            end
          end
        end
      end

      diffs
    end

    # Generate summary report
    def summary : String
      String.build do |io|
        io << "Benchmark Comparison Report\n"
        io << "=" * 40 << "\n"
        io << "Baseline: #{@baseline.git_commit} (#{@baseline.git_branch}) at #{@baseline.timestamp}\n"
        io << "Current:  #{@current.git_commit} (#{@current.git_branch}) at #{@current.timestamp}\n"
        io << "\n"

        # Group by improvement/regression
        improvements = @differences.select(&.improvement)
        regressions = @differences.reject(&.improvement)

        if improvements.any?
          io << "Improvements:\n"
          improvements.each do |diff|
            sign = diff.change_percent > 0 ? "+" : ""
            io << "  #{diff.test_case}.#{diff.metric}: #{sign}#{diff.change_percent.round(2)}%\n"
          end
          io << "\n"
        end

        if regressions.any?
          io << "Regressions:\n"
          regressions.each do |diff|
            sign = diff.change_percent > 0 ? "+" : ""
            io << "  #{diff.test_case}.#{diff.metric}: #{sign}#{diff.change_percent.round(2)}%\n"
          end
          io << "\n"
        end

        # Overall statistics
        total_tests = @differences.size
        passed_tests = improvements.count { |d| d.metric == "iterations_per_second" && d.change_percent > 5.0 }
        io << "Summary: #{passed_tests}/#{total_tests} tests show >5% improvement\n"

        # Check for significant regressions
        significant_regressions = regressions.count { |d| d.change_percent < -10.0 }
        if significant_regressions > 0
          io << "WARNING: #{significant_regressions} tests show >10% regression!\n"
        end
      end
    end

    # Save comparison to file
    def save(directory : String = "comparisons")
      dir_path = File.join("bench", "results", directory)
      Dir.mkdir_p(dir_path)

      filename = "comparison_#{@baseline.timestamp.to_s("%Y%m%d_%H%M%S")}_to_#{@current.timestamp.to_s("%Y%m%d_%H%M%S")}.json"
      filepath = File.join(dir_path, filename)

      result = {
        "baseline_commit"    => @baseline.git_commit,
        "current_commit"     => @current.git_commit,
        "baseline_timestamp" => @baseline.timestamp.to_s,
        "current_timestamp"  => @current.timestamp.to_s,
        "differences"        => @differences.map do |diff|
          {
            "test_case"      => diff.test_case,
            "metric"         => diff.metric,
            "baseline_value" => diff.baseline_value,
            "current_value"  => diff.current_value,
            "change_percent" => diff.change_percent,
            "improvement"    => diff.improvement,
          }
        end,
      }

      File.write(filepath, result.to_pretty_json)
      filepath
    end
  end

  # Result collector for benchmarks
  class ResultCollector
    @results : Hash(String, Hash(String, Hash(String, JSON::Any)))
    @benchmark_name : String

    def initialize(@benchmark_name : String)
      @results = Hash(String, Hash(String, Hash(String, JSON::Any))).new do |h, k|
        h[k] = Hash(String, Hash(String, JSON::Any)).new
      end
    end

    # Record a benchmark result
    def record(
      dataset_size : Int32,
      pattern_type : String,
      method_name : String,
      iterations_per_second : Float64,
      allocation_bytes : Int64? = nil,
    )
      dataset_key = "#{dataset_size}_items"

      @results[dataset_key][pattern_type] ||= {} of String => JSON::Any
      @results[dataset_key][pattern_type][method_name] = JSON::Any.new({
        "iterations_per_second" => JSON::Any.new(iterations_per_second),
        "allocation_bytes"      => JSON::Any.new(allocation_bytes || 0_i64),
      })
    end

    # Create BenchmarkResult from collected data
    def build_result(config : Hash(String, JSON::Any)) : BenchmarkResult
      BenchmarkResult.new(@benchmark_name, config, @results)
    end
  end
end
