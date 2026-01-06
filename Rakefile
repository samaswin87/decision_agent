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
      puts "\n" + "=" * 80
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

  desc "Run benchmarks for all Ruby versions (requires rbenv/rvm)"
  task :all_versions do
    versions = ['3.0', '3.1', '3.2', '3.3']
    versions.each do |version|
      puts "\n" + "=" * 80
      puts "Running benchmarks for Ruby #{version}"
      puts "=" * 80
      system("rbenv local #{version} && bundle install && bundle exec rake benchmark:all") ||
        system("rvm #{version} do bundle install && bundle exec rake benchmark:all") ||
        puts("Warning: Could not switch to Ruby #{version}. Install rbenv or rvm.")
    end
  end
end
