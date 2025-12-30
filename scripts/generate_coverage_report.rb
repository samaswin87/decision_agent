#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

# Script to generate coverage.md from SimpleCov results
class CoverageReportGenerator
  def initialize(resultset_path = "coverage/.resultset.json", last_run_path = "coverage/.last_run.json")
    @resultset_path = resultset_path
    @last_run_path = last_run_path
    @project_root = Pathname.new(__dir__).parent
  end

  def generate
    resultset = load_resultset
    last_run = load_last_run

    files = parse_files(resultset)
    total_coverage = calculate_total_coverage(files)

    markdown = build_markdown(files, total_coverage, last_run)

    output_path = @project_root / "coverage.md"
    File.write(output_path, markdown)

    puts "Coverage report generated: #{output_path}"
    puts "Total coverage: #{total_coverage[:percentage].round(2)}%"
  end

  private

  def load_resultset
    path = @project_root / @resultset_path
    JSON.parse(File.read(path))
  rescue Errno::ENOENT
    raise "Coverage resultset not found at #{path}. Run tests with coverage first."
  end

  def load_last_run
    path = @project_root / @last_run_path
    JSON.parse(File.read(path))
  rescue Errno::ENOENT
    { "result" => { "line" => 0.0 } }
  end

  def parse_files(resultset)
    coverage_data = resultset["RSpec"]&.dig("coverage") || {}

    files = []
    coverage_data.each do |file_path, data|
      path = Pathname.new(file_path)

      # Skip files in examples directory
      next if path.to_s.include?("/examples/")

      # Get relative path from project root
      relative_path = path.relative_path_from(@project_root)

      lines = data["lines"] || []
      relevant_lines = lines.count { |line| !line.nil? }
      covered_lines = lines.count { |line| line&.positive? }

      next if relevant_lines.zero?

      percentage = relevant_lines.positive? ? (covered_lines.to_f / relevant_lines * 100) : 0.0

      files << {
        path: relative_path.to_s,
        percentage: percentage,
        relevant_lines: relevant_lines,
        covered_lines: covered_lines,
        missed_lines: relevant_lines - covered_lines
      }
    end

    files.sort_by { |f| f[:path] }
  end

  def calculate_total_coverage(files)
    total_relevant = files.sum { |f| f[:relevant_lines] }
    total_covered = files.sum { |f| f[:covered_lines] }
    percentage = total_relevant.positive? ? (total_covered.to_f / total_relevant * 100) : 0.0

    {
      percentage: percentage,
      total_files: files.size,
      total_relevant_lines: total_relevant,
      total_covered_lines: total_covered,
      total_missed_lines: total_relevant - total_covered
    }
  end

  def build_markdown(files, total_coverage, last_run)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    last_run.dig("result", "line") || total_coverage[:percentage]

    markdown = <<~MARKDOWN
      # Code Coverage Report

      **Last Updated:** #{timestamp}

      ## Summary

      | Metric | Value |
      |--------|-------|
      | **Total Coverage** | **#{total_coverage[:percentage].round(2)}%** |
      | Total Files | #{total_coverage[:total_files]} |
      | Total Relevant Lines | #{total_coverage[:total_relevant_lines]} |
      | Lines Covered | #{total_coverage[:total_covered_lines]} |
      | Lines Missed | #{total_coverage[:total_missed_lines]} |

      > **Note:** This report excludes files in the `examples/` directory as they are sample code, not production code.

      ## Coverage by File

      | File | Coverage | Lines Covered | Lines Missed | Total Lines |
      |------|----------|---------------|--------------|-------------|
    MARKDOWN

    files.each do |file|
      status_emoji = if file[:percentage] >= 90
                       "\u2705"
                     else
                       file[:percentage] >= 70 ? "\u26A0\uFE0F" : "\u274C"
                     end
      markdown << "| `#{file[:path]}` | #{status_emoji} #{file[:percentage].round(2)}% | " \
                  "#{file[:covered_lines]} | #{file[:missed_lines]} | #{file[:relevant_lines]} |\n"
    end

    markdown << <<~MARKDOWN

      ## Coverage Status

      - ✅ **90%+** - Excellent coverage
      - ⚠️ **70-89%** - Good coverage, improvements recommended
      - ❌ **<70%** - Low coverage, needs attention

      ## How to Generate This Report

      Run the tests with coverage enabled:

      ```bash
      bundle exec rake coverage
      ```

      Or run RSpec directly:

      ```bash
      bundle exec rspec
      ```

      Then regenerate this report:

      ```bash
      ruby scripts/generate_coverage_report.rb
      ```

      ## View Detailed Coverage

      For detailed line-by-line coverage, open `coverage/index.html` in your browser.
    MARKDOWN

    markdown
  end
end

if __FILE__ == $PROGRAM_NAME
  generator = CoverageReportGenerator.new
  generator.generate
end
