# Development Setup Guide

This guide covers setting up the DecisionAgent development environment, including Ruby version management, testing, and development tools.

## Prerequisites

- **Ruby Version Manager**: [asdf](https://asdf-vm.com/) (recommended) or [rbenv](https://github.com/rbenv/rbenv)
- **Ruby Versions**: 3.0.7, 3.1.6, 3.2.5, 3.3.5 (for cross-version testing)
- **Bundler**: Included with Ruby or install via `gem install bundler`

## Installation

### 1. Install asdf (if not already installed)

```bash
# macOS (Homebrew)
brew install asdf

# Linux
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Add asdf to your shell
source ~/.asdf/asdf.sh
```

### 2. Install Ruby Plugin for asdf

```bash
asdf plugin add ruby
```

### 3. Install Required Ruby Versions

```bash
asdf install ruby 3.0.7
asdf install ruby 3.1.6
asdf install ruby 3.2.5
asdf install ruby 3.3.5
```

### 4. Clone the Repository

```bash
git clone https://github.com/samaswin/decision_agent.git
cd decision_agent
```

### 5. Install Dependencies

```bash
# Set Ruby version (use any of the supported versions)
asdf local ruby 3.2.5

# Install gems
bundle install
```

## Development Workflow

### Running Tests

#### Single Ruby Version

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/path/to/test_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

#### Parallel Test Execution

The project uses `parallel_tests` for faster test execution:

```bash
# Setup parallel test databases (first time only)
bundle exec rake parallel:create parallel:setup

# Run tests in parallel (uses all available CPU cores)
bundle exec parallel_rspec spec

# Run with specific number of processes
bundle exec parallel_rspec spec -n 4
```

#### Cross-Ruby Version Testing

Test across all supported Ruby versions automatically:

```bash
./scripts/test_all_ruby_versions.sh
```

This script will:
- Test each Ruby version (3.0.7, 3.1.6, 3.2.5, 3.3.5)
- Run `bundle install` for each version
- Execute RSpec tests with parallel execution
- Generate a summary report with pass/fail status
- Save detailed logs to `/tmp/` for troubleshooting

**Output:**
- Colored status messages for each Ruby version
- Bundle install progress
- Test execution progress
- Final summary showing:
  - Which versions passed ✅
  - Which versions failed ❌
  - Test counts and durations
  - Location of detailed log files

**Log Files:**
- `test_logs/<timestamp>/bundle_install_<version>.log` - Bundle install logs
- `test_logs/<timestamp>/rspec_<version>.log` - Full test output
- `test_logs/<timestamp>/rspec_<version>.json` - JSON test results

Logs are saved in timestamped directories (e.g., `test_logs/20260109_143022/`) so multiple test runs are preserved and not overwritten. The logs are never deleted automatically.

### Running Benchmarks

```bash
# Run all benchmarks
rake benchmark:all

# Run specific benchmarks
rake benchmark:basic      # Basic decision performance
rake benchmark:threads    # Thread-safety and scalability
rake benchmark:regression # Compare against baseline

# See benchmarks/README.md for complete documentation
```

### Code Coverage

The project uses SimpleCov for code coverage tracking:

```bash
# Run tests with coverage
bundle exec rspec

# View coverage report
open coverage/index.html
```

Coverage reports are automatically generated in the `coverage/` directory.

## Project Structure

```
decision_agent/
├── lib/                    # Main library code
│   └── decision_agent/    # Core modules
├── spec/                   # Test suite
├── examples/               # Example code
├── docs/                   # Documentation
├── benchmarks/             # Performance benchmarks
├── scripts/                # Utility scripts
│   └── test_all_ruby_versions.sh  # Multi-version testing
├── Gemfile                 # Dependencies
└── Rakefile                # Rake tasks
```

## Development Dependencies

Key development dependencies:

- **rspec** (~> 3.12) - Testing framework
- **parallel_tests** (~> 3.0) - Parallel test execution
- **simplecov** (~> 0.22) - Code coverage
- **rubocop** (~> 1.60) - Code style checker
- **benchmark-ips** - Performance benchmarking
- **webmock** (~> 3.18) - HTTP request mocking

## Testing Best Practices

1. **Run tests before committing**: Always run the full test suite
2. **Test across Ruby versions**: Use `./scripts/test_all_ruby_versions.sh` before major changes
3. **Maintain coverage**: Keep test coverage above 85%
4. **Use parallel tests**: Significantly faster for large test suites
5. **Check for regressions**: Run benchmarks after performance-related changes

## Troubleshooting

### Ruby Version Not Detected

If the multi-version test script skips a Ruby version:

```bash
# Verify version is installed
asdf list ruby

# Reinstall if needed
asdf uninstall ruby 3.2.5
asdf install ruby 3.2.5
```

### Bundle Install Fails

```bash
# Clean bundle cache
bundle clean --force

# Reinstall gems
bundle install
```

### Parallel Tests Fail

```bash
# Reset parallel test databases
bundle exec rake parallel:drop
bundle exec rake parallel:create parallel:setup
```

### Test Failures on Specific Ruby Version

Check the detailed logs in `/tmp/rspec_<version>.log` for specific error messages.

## CI/CD Integration

The multi-Ruby version testing script can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Test all Ruby versions
  run: ./scripts/test_all_ruby_versions.sh
```

## Additional Resources

- [Main README](../README.md) - Project overview and quick start
- [Code Examples](CODE_EXAMPLES.md) - Usage examples
- [Changelog](CHANGELOG.md) - Version history
- [Contributing Guide](../README.md#contributing) - Contribution guidelines
