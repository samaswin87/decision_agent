#!/usr/bin/env ruby
# Script to run all examples and verify they pass

require 'fileutils'

examples_dir = File.join(__dir__, '..', 'examples')
example_files = Dir.glob(File.join(examples_dir, '**', '*.rb')).sort

puts "Found #{example_files.length} example files to run\n\n"

results = []
failed_examples = []

example_files.each do |example_file|
  relative_path = example_file.sub("#{examples_dir}/", '')
  print "Running #{relative_path}... "
  
  # Skip examples that start servers or are interactive
  skip_patterns = [
    '03_sinatra_app.rb',  # Starts a server
    '02_rails_integration.rb',  # Requires Rails setup
    '04_rails_web_ui_integration.rb',  # Requires Rails setup
    'rails_rbac_integration.rb',  # Requires Rails setup
  ]
  
  if skip_patterns.any? { |pattern| relative_path.include?(pattern) }
    puts "SKIPPED (requires special setup)"
    results << { file: relative_path, status: 'skipped', reason: 'requires special setup' }
    next
  end
  
  # Run the example with CI environment set (to avoid starting servers)
  cmd = "bundle exec ruby #{example_file}"
  # Use env to pass CI variables
  env_vars = "CI=true GITHUB_ACTIONS=true "
  output = `#{env_vars}#{cmd} 2>&1`
  exit_code = $?.exitstatus
  
  if exit_code == 0
    puts "✓ PASSED"
    results << { file: relative_path, status: 'passed' }
  else
    puts "✗ FAILED (exit code: #{exit_code})"
    failed_examples << relative_path
    results << { file: relative_path, status: 'failed', exit_code: exit_code, output: output }
  end
end

puts "\n" + "="*80
puts "SUMMARY"
puts "="*80

passed = results.count { |r| r[:status] == 'passed' }
failed = results.count { |r| r[:status] == 'failed' }
skipped = results.count { |r| r[:status] == 'skipped' }

puts "Total examples: #{results.length}"
puts "Passed: #{passed}"
puts "Failed: #{failed}"
puts "Skipped: #{skipped}"

if failed_examples.any?
  puts "\nFAILED EXAMPLES:"
  failed_examples.each do |file|
    result = results.find { |r| r[:file] == file }
    puts "  - #{file} (exit code: #{result[:exit_code]})"
    if result[:output] && result[:output].length > 0
      # Show last 20 lines of output
      # Force UTF-8 encoding to avoid encoding errors
      output = result[:output].force_encoding('UTF-8')
      lines = output.split("\n")
      puts "    Last output lines:"
      lines.last(10).each do |line|
        puts "      #{line}"
      end
    end
  end
  exit 1
else
  puts "\n✅ All runnable examples passed!"
  exit 0
end

