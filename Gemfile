source "https://rubygems.org"

gemspec

group :development, :test do
  gem "activerecord", "~> 7.0"
  gem "activesupport", "< 7.2" # Pin to version compatible with Ruby 3.0+
  gem "benchmark_driver" # Advanced benchmarking framework for testing benchmarks
  gem "benchmark-ips" # Better benchmark statistics
  gem "connection_pool", "< 3.0" # Pin to version compatible with Ruby 3.0+
  gem "memory_profiler" # Memory profiling
  gem "minitest", "< 6.0" # Pin to version compatible with Ruby 3.0+
  gem "parallel_tests", "~> 3.0" # Parallel test execution
  gem "public_suffix", "< 7.0" # Pin to version compatible with Ruby 3.1 (7.0+ requires Ruby >= 3.2)
  gem "puma"
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.12"
  gem "ruby-prof" # Detailed profiling (optional)
  gem "simplecov", "~> 0.22", require: false
  gem "sqlite3", "~> 1.6"
  gem "webmock", "~> 3.18" # For HTTP request mocking in tests
end
