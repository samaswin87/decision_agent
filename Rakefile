require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Run all tests"
task test: :spec

desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task[:spec].invoke
end

desc "Open IRB console with gem loaded"
task :console do
  require "irb"
  require "decision_agent"
  ARGV.clear
  IRB.start
end

# ============================================================================
# Benchmark Tasks
# ============================================================================
namespace :benchmark do
  desc "Run all benchmarks"
  task :all do
    puts "Running all benchmarks..."
    Dir.glob("benchmarks/*_benchmark.rb").each do |file|
      next if file.include?("regression")

      puts "\n#{'=' * 80}"
      puts "Running #{File.basename(file)}..."
      puts "=" * 80
      system("bundle exec ruby #{file}")
      puts
    end
  end

  desc "Run basic decision benchmark"
  task :basic do
    system("bundle exec ruby benchmarks/basic_decision_benchmark.rb")
  end

  desc "Run thread-safety benchmark"
  task :threads do
    system("bundle exec ruby benchmarks/thread_safety_benchmark.rb")
  end

  desc "Run evaluator comparison benchmark"
  task :evaluators do
    system("bundle exec ruby benchmarks/evaluator_comparison.rb")
  end

  desc "Run operator performance benchmark"
  task :operators do
    system("bundle exec ruby benchmarks/operator_performance.rb")
  end

  desc "Run memory benchmark"
  task :memory do
    system("bundle exec ruby benchmarks/memory_benchmark.rb")
  end

  desc "Run batch throughput benchmark"
  task :batch do
    system("bundle exec ruby benchmarks/batch_throughput.rb")
  end

  desc "Run regression benchmark (compare against baseline)"
  task :regression do
    system("bundle exec ruby benchmarks/regression_benchmark.rb")
  end

  desc "Update baseline results for current Ruby version"
  task :baseline do
    ruby_version = "#{RUBY_VERSION.split('.')[0]}.#{RUBY_VERSION.split('.')[1]}"
    puts "Updating baseline results for Ruby #{ruby_version}..."
    system("bundle exec ruby benchmarks/regression_benchmark.rb --update-baseline")
  end

  desc "Update README with latest benchmark results"
  task :update_readme do
    require "json"
    require "fileutils"

    results_dir = File.join(__dir__, "benchmarks", "results")
    result_files = Dir.glob(File.join(results_dir, "results_*.json"))
      .sort_by { |f| File.mtime(f) }
      .reverse
      .first(2)

    if result_files.length < 2
      puts "⚠️  Need at least 2 benchmark results to compare"
      exit 1
    end

    latest = JSON.parse(File.read(result_files[0]))
    previous = JSON.parse(File.read(result_files[1]))

    def calculate_change(old_val, new_val, is_latency = false)
      return "N/A" if old_val.nil? || new_val.nil? || old_val == 0

      change_pct = ((new_val - old_val) / old_val * 100).round(2)

      if is_latency
        if change_pct < 0
          "↓ #{change_pct.abs}% (improved)"
        elsif change_pct > 0
          "↑ #{change_pct}% (degraded)"
        else
          "→ 0% (no change)"
        end
      else
        if change_pct > 0
          "↑ #{change_pct}% (improved)"
        elsif change_pct < 0
          "↓ #{change_pct.abs}% (degraded)"
        else
          "→ 0% (no change)"
        end
      end
    end

    markdown = <<~MARKDOWN
### Latest Benchmark Results

**Last Updated:** #{latest["timestamp"]}

#### Performance Comparison

| Metric | Latest (#{latest["timestamp"].split("T").first}) | Previous (#{previous["timestamp"].split("T").first}) | Change |
|--------|--------------------------------------------------|------------------------------------------------------|--------|
| Basic Throughput | #{latest["results"]["basic_throughput"]} decisions/sec | #{previous["results"]["basic_throughput"]} decisions/sec | #{calculate_change(previous["results"]["basic_throughput"], latest["results"]["basic_throughput"])} |
| Basic Latency | #{latest["results"]["basic_latency_ms"]} ms | #{previous["results"]["basic_latency_ms"]} ms | #{calculate_change(previous["results"]["basic_latency_ms"], latest["results"]["basic_latency_ms"], true)} |
| Multi-threaded (50 threads) Throughput | #{latest["results"]["thread_50_throughput"]} decisions/sec | #{previous["results"]["thread_50_throughput"]} decisions/sec | #{calculate_change(previous["results"]["thread_50_throughput"], latest["results"]["thread_50_throughput"])} |
| Multi-threaded (50 threads) Latency | #{latest["results"]["thread_50_latency_ms"]} ms | #{previous["results"]["thread_50_latency_ms"]} ms | #{calculate_change(previous["results"]["thread_50_latency_ms"], latest["results"]["thread_50_latency_ms"], true)} |

**Environment:**
- Ruby Version: #{latest["ruby_version"]}
- Hardware: #{latest["hardware"]}
- OS: #{latest["os"]}
- Git Commit: `#{latest["git_commit"][0..7]}`

> 💡 **Note:** Run `rake benchmark:regression` to generate new benchmark results. This section is automatically updated with the last 2 benchmark runs.
MARKDOWN

    # Read README with UTF-8 encoding
    readme_path = File.join(__dir__, "README.md")
    readme_content = File.read(readme_path, encoding: "UTF-8")

    # Find and replace the benchmark section
    start_marker = "### Latest Benchmark Results"
    end_marker = "> 💡 **Note:** Run `rake benchmark:regression`"

    start_idx = readme_content.index(start_marker)
    if start_idx
      # Find the end of the section (next ## or end of file)
      remaining = readme_content[start_idx..-1]
      end_idx = remaining.index(/^## /m)
      end_idx = end_idx ? start_idx + end_idx : readme_content.length
      
      # Find the end of the note (two newlines after the note)
      note_start = readme_content.index(end_marker, start_idx)
      if note_start
        note_end = readme_content.index("\n\n", note_start) || readme_content.index("\n", note_start + 1) || end_idx
        note_end = readme_content.index("\n", note_end + 1) || end_idx
      else
        note_end = end_idx
      end

      readme_content[start_idx...note_end] = markdown.chomp
    else
      # Insert after "Run Benchmarks" section
      insert_point = readme_content.index("# See [Benchmarks Guide](benchmarks/README.md) for complete documentation")
      if insert_point
        insert_point = readme_content.index("\n", insert_point) + 1
        readme_content.insert(insert_point, "\n" + markdown)
      end
    end

    File.write(readme_path, readme_content, encoding: "UTF-8")
    puts "✅ README updated with latest benchmark results"
  end

  desc "Run benchmarks for all Ruby versions (requires rbenv/rvm)"
  task :all_versions do
    versions = ["3.0", "3.1", "3.2", "3.3"]
    versions.each do |version|
      puts "\n#{'=' * 80}"
      puts "Running benchmarks for Ruby #{version}"
      puts "=" * 80
      system("rbenv local #{version} && bundle install && bundle exec rake benchmark:all") ||
        system("rvm #{version} do bundle install && bundle exec rake benchmark:all") ||
        puts("Warning: Could not switch to Ruby #{version}. Install rbenv or rvm.")
    end
  end
end
