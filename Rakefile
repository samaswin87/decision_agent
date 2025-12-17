require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Run all tests"
task test: :spec

desc "Run tests with coverage"
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

desc "Open IRB console with gem loaded"
task :console do
  require "irb"
  require "decision_agent"
  ARGV.clear
  IRB.start
end
