# DecisionAgent Benchmarks

Comprehensive benchmark suite for measuring DecisionAgent performance, identifying bottlenecks, and tracking performance regressions over time.

**Related Documentation:**
- [Main README](../README.md) - Overview and installation
- [Performance & Thread-Safety Guide](../docs/PERFORMANCE_AND_THREAD_SAFETY.md) - Performance analysis and benchmarks
- [Thread-Safety Implementation](../docs/THREAD_SAFETY.md) - Technical implementation details

## Quick Start

```bash
# Run all benchmarks
rake benchmark:all

# Run specific benchmark
rake benchmark:basic
rake benchmark:threads
rake benchmark:evaluators
rake benchmark:operators
rake benchmark:memory
rake benchmark:batch

# Run regression test (compare against baseline)
rake benchmark:regression

# Update baseline for current Ruby version
rake benchmark:baseline
```

## Benchmark Descriptions

### Basic Decision Benchmark (`basic_decision_benchmark.rb`)

Tests core decision-making performance with:
- Single condition rules
- Multiple conditions (all/any operators)
- Single evaluator performance
- Multiple evaluators with conflict resolution
- Large rule sets (10, 50, 100 rules)

**Expected Performance:**
- Single condition: ~8,500 decisions/sec
- Multiple conditions: ~7,200 decisions/sec
- Large rule set (100): ~5,000 decisions/sec

### Thread-Safety Benchmark (`thread_safety_benchmark.rb`)

Tests multi-threaded performance and scalability:
- Single-threaded baseline
- Multi-threaded (10, 50, 100 threads)
- Shared agent instance safety
- Immutability overhead
- Thread scalability

**Expected Performance:**
- Single thread: ~7,800 decisions/sec
- 10 threads: ~15,200 decisions/sec
- 50 threads: ~35,000 decisions/sec
- 100 threads: ~60,000 decisions/sec
- Overhead: < 2% (minimal)

### Evaluator Comparison (`evaluator_comparison.rb`)

Compares JSON and DMN evaluator performance:
- Initialization time (JSON vs DMN)
- Evaluation latency comparison
- Hit policy overhead (FIRST, UNIQUE, PRIORITY, COLLECT, ANY)
- XML parsing overhead

**Expected Performance:**
- JSON init: ~0.5ms per evaluator
- DMN init: ~2.5ms per evaluator (+400%)
- JSON eval: ~0.13ms per evaluation
- DMN eval (FIRST): ~0.14ms per evaluation (+7.7%)

### Operator Performance (`operator_performance.rb`)

Tests performance impact of different operator types:
- Basic operators (gt, eq, lt)
- String operators (matches, contains, etc.)
- Numeric operators (between, modulo, etc.)
- Date operators
- Geospatial operators
- Collection operators

**Expected Performance:**
- Basic operators: ~8,500 decisions/sec (baseline)
- String operators: ~7,800 decisions/sec (-8.2%)
- Numeric operators: ~8,200 decisions/sec (-3.5%)
- Date operators: ~7,900 decisions/sec (-7.1%)
- Geospatial operators: ~6,500 decisions/sec (-23.5%)
- Collection operators: ~7,000 decisions/sec (-17.6%)

### Memory Benchmark (`memory_benchmark.rb`)

Measures memory usage patterns:
- Memory per decision
- Peak memory usage
- Memory allocations
- GC impact

**Expected Performance:**
- Memory per decision: ~2.5 KB
- Peak memory (10k): ~25 MB
- Allocations per decision: ~150 objects
- GC impact: < 1% overhead

### Batch Throughput (`batch_throughput.rb`)

Tests real-world high-throughput scenarios:
- High-throughput API scenario (1000+ req/sec)
- Complex business rules (loan approval, fraud detection)
- Large rule sets (100+ rules)
- Deeply nested context data

**Expected Performance:**
- Loan approval (simple): ~8,000 decisions/sec
- Loan approval (complex): ~4,500 decisions/sec
- Fraud detection: ~6,200 decisions/sec
- Large rule set (200): ~3,500 decisions/sec

### Regression Benchmark (`regression_benchmark.rb`)

Tracks performance over time and detects regressions:
- Compares current results against baseline
- Alerts on >10% performance degradation
- Supports multiple Ruby versions (3.0, 3.1, 3.2, 3.3)
- Stores version-specific baselines

## Performance Expectations

Based on Intel i7-7820HQ @ 2.90GHz:
- **Basic decisions**: 7,500-8,500 decisions/sec
- **With validation**: 7,000-8,000 decisions/sec
- **Multi-threaded (50 threads)**: 35,000+ decisions/sec
- **Average latency**: 0.12-0.13ms per decision

**Note:** Performance varies significantly by hardware:
- **Apple M1/M2/M3 (2020+)**: ~8,500-9,000+ decisions/sec
- **Intel i7/i9 (2017-2020)**: ~7,500-8,000 decisions/sec
- **Older hardware**: ~5,000-7,000 decisions/sec

## Baseline Management

### Creating a Baseline

```bash
# Update baseline for current Ruby version
rake benchmark:baseline
```

This creates a baseline file at:
```
benchmarks/baselines/basic_baseline_{ruby_version}.json
```

### Baseline Format

Baselines are stored as JSON files with the following structure:

```json
{
  "timestamp": "2026-01-15T10:00:00Z",
  "ruby_version": "3.3.5",
  "ruby_major_minor": "3.3",
  "git_commit": "abc123def456",
  "hardware": "x86_64",
  "os": "Darwin",
  "results": {
    "basic_throughput": 7834,
    "basic_latency_ms": 0.1276,
    "thread_50_throughput": 35000,
    "thread_50_latency_ms": 0.1429
  }
}
```

### Multi-Version Testing

Baselines are stored separately for each Ruby version:
- `basic_baseline_3.0.json`
- `basic_baseline_3.1.json`
- `basic_baseline_3.2.json`
- `basic_baseline_3.3.json`

## Running Benchmarks

### Local Execution

```bash
# Run all benchmarks
rake benchmark:all

# Run specific benchmark
bundle exec ruby benchmarks/basic_decision_benchmark.rb
```

**Results Storage:**
- Benchmark results are saved to `benchmarks/results/` directory
- Baseline files are stored in `benchmarks/baselines/` directory
- Results include timestamp, Ruby version, and performance metrics

### Docker Execution

#### Using the Convenience Script

The easiest way to run benchmarks in Docker is using the `run_in_docker.sh` script:

```bash
# Run all benchmarks with Ruby 3.3 (default)
./benchmarks/run_in_docker.sh

# Run all benchmarks with a specific Ruby version
./benchmarks/run_in_docker.sh 3.2

# Run a specific benchmark with Ruby 3.3
./benchmarks/run_in_docker.sh 3.3 basic

# Run regression test with Ruby 3.1
./benchmarks/run_in_docker.sh 3.1 regression

# Update baseline with Ruby 3.0
./benchmarks/run_in_docker.sh 3.0 baseline

# Force rebuild of Docker image
./benchmarks/run_in_docker.sh 3.3 all --build
```

#### Using Docker Compose Directly

You can also use docker-compose directly:

```bash
# Run all benchmarks in Docker (Ruby 3.3)
docker-compose -f benchmarks/docker-compose.yml run --rm benchmark-3.3 rake benchmark:all

# Run specific benchmark
docker-compose -f benchmarks/docker-compose.yml run --rm benchmark-3.3 rake benchmark:basic
```

### CI/CD Execution

Benchmarks run automatically in CI/CD on:
- Pull requests (when `lib/**` or `benchmarks/**` files change)
- Weekly schedule (Sunday at midnight)
- All supported Ruby versions (3.0, 3.1, 3.2, 3.3)

## Best Practices

### Warm-up Phase

Always warm up before measuring:
- Allows JIT compilation
- Populates caches
- Stabilizes GC

### Iteration Counts

- **Quick tests**: 1,000-5,000 iterations (for development)
- **Standard tests**: 10,000 iterations (for CI/CD)
- **Comprehensive tests**: 50,000-100,000 iterations (for detailed analysis)

### Environment

- Run on a dedicated machine with minimal background processes
- Document hardware (CPU model, RAM, Ruby version, OS)
- Run benchmarks 3-5 times and average results
- Maintain consistent conditions (same machine, same time of day)

### Configuration

- Disable validation: Use `validate_evaluations: false` for maximum performance
- Production mode: Set `ENV['RACK_ENV'] = 'production'` if applicable
- GC tuning: Consider `RUBY_GC_HEAP_INIT_SLOTS` for consistent results

## Adding New Benchmarks

1. Create new file in `benchmarks/` directory
2. Follow the standard template:
   ```ruby
   #!/usr/bin/env ruby
   # frozen_string_literal: true
   
   require "bundler/setup"
   require "decision_agent"
   require "benchmark"
   
   # Configuration
   ITERATIONS = 10_000
   WARMUP_ITERATIONS = 100
   
   # Setup
   # ... create evaluators, agents, test data
   
   # Warm-up
   WARMUP_ITERATIONS.times { agent.decide(context: test_context) }
   
   # Benchmark
   time = Benchmark.realtime do
     ITERATIONS.times { agent.decide(context: test_context) }
   end
   
   # Calculate and display results
   ```
3. Add Rake task to `Rakefile`
4. Update this README

## Troubleshooting

### Performance Varies Significantly

Performance is highly dependent on:
- Hardware generation (newer = faster)
- System load (run on dedicated machine)
- Ruby version (3.2+ generally faster)
- Background processes (minimize interference)

### Baseline Comparison Fails

- Ensure baseline exists for your Ruby version
- Check baseline file format (valid JSON)
- Verify you're comparing same Ruby version
- Update baseline if hardware changed

### Memory Profiler Not Available

Install the gem:
```bash
gem install memory_profiler
```

Or add to Gemfile:
```ruby
gem "memory_profiler"
```

### Docker Issues

- Ensure Docker is running
- Check Docker Compose version (3.8+)
- Verify volume mounts are correct
- Check resource limits (CPU/memory)

## Resources

### Documentation

- [Main README](../README.md) - Overview and installation
- [Performance & Thread-Safety Guide](../docs/PERFORMANCE_AND_THREAD_SAFETY.md) - Performance documentation
- [Thread-Safety Implementation](../docs/THREAD_SAFETY.md) - Thread-safety details

### Examples

- [../examples/thread_safe_performance.rb](../examples/thread_safe_performance.rb) - Thread-safety example
- [../examples/dmn_vs_json_performance.rb](../examples/dmn_vs_json_performance.rb) - Evaluator comparison
- [../examples/advanced_operators_performance.rb](../examples/advanced_operators_performance.rb) - Operator performance

### Tools

- [benchmark-ips](https://github.com/evanphx/benchmark-ips) - Better benchmark statistics
- [memory_profiler](https://github.com/SamSaffron/memory_profiler) - Memory profiling
- [ruby-prof](https://github.com/ruby-prof/ruby-prof) - Detailed profiling

## Maintenance

### Regular Tasks

- **Weekly**: Run full benchmark suite
- **Monthly**: Review and update baselines if hardware changes
- **Per Release**: Run regression tests before release
- **On PR**: Run quick benchmarks for performance-critical changes

### Baseline Updates

Update baselines when:
- Hardware changes (update all Ruby version baselines)
- Ruby version changes (create new baseline for new version)
- Significant code optimizations (update all Ruby version baselines)
- Major feature additions (update all Ruby version baselines)

---

**Last Updated**: 2026-01-15  
**Status**: Active  
**Ruby Versions Supported**: 3.0, 3.1, 3.2, 3.3

