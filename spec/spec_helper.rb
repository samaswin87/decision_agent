require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/examples/"
end

require "decision_agent"

# Load ActiveRecord for thread-safety and integration tests
begin
  require "active_record"
  require "sqlite3"
  require "decision_agent/versioning/activerecord_adapter"
rescue LoadError
  # ActiveRecord is optional - tests will be skipped if not available
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
