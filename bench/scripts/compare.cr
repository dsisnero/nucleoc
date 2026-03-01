#!/usr/bin/env crystal
require "json"
require "../results/result_manager"

# Simple comparison tool
def compare_files(baseline_path : String, current_path : String)
  puts "Comparing: #{File.basename(baseline_path)}"

  begin
    baseline = NucleocBench::BenchmarkResult.load(baseline_path)
    current = NucleocBench::BenchmarkResult.load(current_path)

    comparison = baseline.compare(current)

    puts comparison.summary
    puts

    # Save comparison
    comparison_file = comparison.save
    puts "Comparison saved to: #{comparison_file}"
  rescue ex : JSON::ParseException
    puts "  Error parsing JSON: #{ex.message}"
  rescue ex : KeyError
    puts "  Error: Missing expected field in JSON"
  end
end

# Main execution
if ARGV.size >= 2
  # Compare specific files
  compare_files(ARGV[0], ARGV[1])
elsif ARGV.size == 1 && ARGV[0] == "all"
  # Compare all files in baseline vs current
  baseline_dir = "bench/results/baseline"
  current_dir = "bench/results/current"

  unless Dir.exists?(baseline_dir) && Dir.exists?(current_dir)
    puts "Error: Baseline or current directory not found"
    exit 1
  end

  # Find all JSON files
  baseline_files = Dir.glob(File.join(baseline_dir, "*.json"))
  current_files = Dir.glob(File.join(current_dir, "*.json"))

  if baseline_files.empty? || current_files.empty?
    puts "Error: No JSON files found in baseline or current directory"
    exit 1
  end

  # Match files by name
  baseline_files.each do |baseline_path|
    filename = File.basename(baseline_path)
    current_path = File.join(current_dir, filename)

    if File.exists?(current_path)
      compare_files(baseline_path, current_path)
      puts "=" * 60
      puts
    else
      puts "Warning: No matching current file for #{filename}"
      puts
    end
  end
else
  puts "Usage:"
  puts "  ./bench/scripts/compare.cr [baseline_file] [current_file]"
  puts "  ./bench/scripts/compare.cr all"
  puts
  puts "Or use the shell script:"
  puts "  ./bench/scripts/compare_results.sh"
end
