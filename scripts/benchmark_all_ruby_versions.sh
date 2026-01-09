#!/usr/bin/env bash

# Script to run performance benchmarks for decision_agent across multiple Ruby versions using asdf
#
# This script will:
#   1. Test each Ruby version (3.0.7, 3.1.6, 3.2.5, 3.3.5)
#   2. Run bundle install for each version
#   3. Run performance benchmarks for each version
#   4. Generate a summary report with results
#
# Requirements:
#   - asdf installed and in PATH
#   - Ruby versions installed via asdf: asdf install ruby 3.0.7 (etc.)
#
# Usage:
#   ./scripts/benchmark_all_ruby_versions.sh
#
# Output:
#   - Console output with colored status messages
#   - Log files in benchmark_logs/<timestamp>/ for bundle install and benchmark results
#   - Benchmark results in benchmark_logs/<timestamp>/benchmark_<version>.log
#   - Logs are preserved and not deleted (organized by timestamp)

# Don't exit on error - we want to benchmark all versions even if one fails
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ruby versions to test
RUBY_VERSIONS=("3.0.7" "3.1.6" "3.2.5" "3.3.5")

# Results storage (using functions instead of associative arrays for bash 3.2 compatibility)
RESULTS_DIR="/tmp/ruby_benchmark_results"
mkdir -p "$RESULTS_DIR"

# Log directory - save logs in project directory so they persist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/benchmark_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CURRENT_LOG_DIR="${LOG_DIR}/${TIMESTAMP}"
mkdir -p "$CURRENT_LOG_DIR"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if asdf is available
check_asdf() {
    if ! command -v asdf &> /dev/null; then
        print_status "$RED" "ERROR: asdf is not installed or not in PATH"
        exit 1
    fi
}

# Function to source asdf
source_asdf() {
    local asdf_path
    if [ -f "$HOME/.asdf/asdf.sh" ]; then
        asdf_path="$HOME/.asdf/asdf.sh"
    elif [ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]; then
        asdf_path="/usr/local/opt/asdf/libexec/asdf.sh"
    elif [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
        asdf_path="/opt/homebrew/opt/asdf/libexec/asdf.sh"
    else
        # Try to find asdf.sh
        asdf_path=$(find /usr/local /opt "$HOME" -name "asdf.sh" 2>/dev/null | head -1)
    fi
    
    if [ -n "$asdf_path" ] && [ -f "$asdf_path" ]; then
        source "$asdf_path" 2>/dev/null || true
    fi
}

# Function to check if Ruby version is installed
check_ruby_version() {
    local version=$1
    source_asdf
    # Check for version with optional asterisk (current version) and optional spaces
    # Pattern matches: "  3.2.5" or " *3.2.5" or "*3.2.5"
    if ! asdf list ruby 2>/dev/null | grep -qE "^\s*\*?\s*${version}"; then
        print_status "$YELLOW" "WARNING: Ruby ${version} is not installed. Skipping..."
        return 1
    fi
    return 0
}

# Function to setup Ruby environment in a subshell
setup_ruby_env() {
    local version=$1
    source_asdf
    
    # Get the Ruby installation path for this version
    local ruby_path=$(asdf which ruby "$version" 2>/dev/null)
    if [ -z "$ruby_path" ]; then
        # Try alternative method
        local asdf_ruby_dir=$(asdf where ruby "$version" 2>/dev/null)
        if [ -n "$asdf_ruby_dir" ]; then
            ruby_path="$asdf_ruby_dir/bin/ruby"
        fi
    fi
    
    if [ -n "$ruby_path" ] && [ -f "$ruby_path" ]; then
        local ruby_bin=$(dirname "$ruby_path")
        export PATH="$ruby_bin:$PATH"
        # Also set GEM_HOME and GEM_PATH
        local gem_home=$(dirname "$ruby_bin")/lib/ruby/gems
        if [ -d "$gem_home" ]; then
            export GEM_HOME="$gem_home"
            export GEM_PATH="$gem_home"
        fi
        # Set ASDF_RUBY_VERSION for asdf
        export ASDF_RUBY_VERSION="$version"
    else
        # Fallback: try asdf shell (may not work in subshell)
        eval "$(asdf shell ruby "$version" 2>/dev/null)" || true
    fi
}

# Function to run bundle install
run_bundle_install() {
    local version=$1
    print_status "$BLUE" "  → Running bundle install..."
    
    # Run bundle install in a subshell with the specified Ruby version
    local log_file="${CURRENT_LOG_DIR}/bundle_install_${version}.log"
    local exit_file="${CURRENT_LOG_DIR}/bundle_install_${version}.exit"
    
    (
        setup_ruby_env "$version"
        bundle install --quiet 2>&1
        echo $? > "$exit_file"
    ) | tee "$log_file"
    
    local exit_code=$(cat "$exit_file" 2>/dev/null || echo "1")
    rm -f "$exit_file"
    
    if [ "$exit_code" = "0" ]; then
        echo "SUCCESS" > "$RESULTS_DIR/bundle_${version}"
        print_status "$GREEN" "  ✓ Bundle install successful"
        return 0
    else
        echo "FAILED" > "$RESULTS_DIR/bundle_${version}"
        print_status "$RED" "  ✗ Bundle install failed"
        return 1
    fi
}

# Function to run performance benchmarks
run_benchmarks() {
    local version=$1
    print_status "$BLUE" "  → Running performance benchmarks..."
    
    # Run benchmarks in a subshell with the specified Ruby version
    local log_file="${CURRENT_LOG_DIR}/benchmark_${version}.log"
    local exit_file="${CURRENT_LOG_DIR}/benchmark_${version}.exit"
    
    (
        setup_ruby_env "$version"
        cd "$PROJECT_ROOT"
        bundle exec rake benchmark:all 2>&1
        echo $? > "$exit_file"
    ) | tee "$log_file"
    
    local exit_code=$(cat "$exit_file" 2>/dev/null || echo "1")
    rm -f "$exit_file"
    echo "$exit_code" > "$RESULTS_DIR/exit_${version}"
    
    if [ "$exit_code" = "0" ]; then
        echo "PASSED" > "$RESULTS_DIR/benchmark_${version}"
        print_status "$GREEN" "  ✓ All benchmarks completed successfully"
        return 0
    else
        echo "FAILED" > "$RESULTS_DIR/benchmark_${version}"
        print_status "$RED" "  ✗ Benchmarks failed (exit code: $exit_code)"
        return 1
    fi
}

# Function to extract benchmark summary from log
extract_benchmark_summary() {
    local version=$1
    local log_file="${CURRENT_LOG_DIR}/benchmark_${version}.log"
    
    if [ -f "$log_file" ]; then
        # Extract key performance metrics from the log
        print_status "$BLUE" "  → Key Performance Metrics:"
        
        # Try to extract throughput numbers (decisions/sec)
        local throughput=$(grep -E "decisions/sec|decisions per second|throughput" "$log_file" | head -3 | sed 's/^/    /')
        if [ -n "$throughput" ]; then
            echo "$throughput"
        fi
        
        # Try to extract latency numbers
        local latency=$(grep -E "latency|ms per decision|average.*ms" "$log_file" | head -3 | sed 's/^/    /')
        if [ -n "$latency" ]; then
            echo "$latency"
        fi
        
        # If no specific metrics found, show last few lines
        if [ -z "$throughput" ] && [ -z "$latency" ]; then
            echo "    (See log file for detailed results)"
        fi
    else
        echo "    (Benchmark log file not found)"
    fi
}

# Function to benchmark a single Ruby version
benchmark_ruby_version() {
    local version=$1
    
    print_status "$BLUE" "\n=========================================="
    print_status "$BLUE" "Benchmarking Ruby ${version}"
    print_status "$BLUE" "=========================================="
    
    # Check if version is installed
    if ! check_ruby_version "$version"; then
        echo "SKIPPED" > "$RESULTS_DIR/result_${version}"
        return 1
    fi
    
    # Verify Ruby version is accessible
    print_status "$BLUE" "  → Verifying Ruby ${version}..."
    local current_version=$(
        setup_ruby_env "$version"
        ruby -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo ""
    )
    
    if [ -z "$current_version" ]; then
        print_status "$RED" "  ✗ Could not verify Ruby ${version}"
        echo "SKIPPED" > "$RESULTS_DIR/result_${version}"
        return 1
    elif [ "$current_version" != "$version" ]; then
        print_status "$YELLOW" "  WARNING: Expected Ruby ${version}, but got ${current_version}"
    else
        print_status "$GREEN" "  ✓ Using Ruby ${version}"
    fi
    
    # Run bundle install with the specified Ruby version
    if ! run_bundle_install "$version"; then
        echo "BUNDLE_FAILED" > "$RESULTS_DIR/result_${version}"
        return 1
    fi
    
    # Run performance benchmarks with the specified Ruby version
    if run_benchmarks "$version"; then
        echo "SUCCESS" > "$RESULTS_DIR/result_${version}"
        extract_benchmark_summary "$version"
        return 0
    else
        echo "BENCHMARK_FAILED" > "$RESULTS_DIR/result_${version}"
        extract_benchmark_summary "$version"
        return 1
    fi
}

# Function to print final summary
print_summary() {
    print_status "$BLUE" "\n=========================================="
    print_status "$BLUE" "BENCHMARK SUMMARY"
    print_status "$BLUE" "=========================================="
    
    local total=0
    local passed=0
    local failed=0
    local skipped=0
    
    for version in "${RUBY_VERSIONS[@]}"; do
        total=$((total + 1))
        local result=$(cat "$RESULTS_DIR/result_${version}" 2>/dev/null || echo "UNKNOWN")
        case "$result" in
            "SUCCESS")
                print_status "$GREEN" "✓ Ruby ${version}: SUCCESS"
                passed=$((passed + 1))
                ;;
            "BUNDLE_FAILED")
                print_status "$RED" "✗ Ruby ${version}: BUNDLE INSTALL FAILED"
                failed=$((failed + 1))
                ;;
            "BENCHMARK_FAILED")
                print_status "$RED" "✗ Ruby ${version}: BENCHMARKS FAILED"
                failed=$((failed + 1))
                ;;
            "SKIPPED")
                print_status "$YELLOW" "⊘ Ruby ${version}: SKIPPED (not installed)"
                skipped=$((skipped + 1))
                ;;
            *)
                print_status "$YELLOW" "? Ruby ${version}: UNKNOWN STATUS"
                ;;
        esac
        
        # Show bundle status
        local bundle_result=$(cat "$RESULTS_DIR/bundle_${version}" 2>/dev/null || echo "")
        if [ -n "$bundle_result" ]; then
            if [ "$bundle_result" = "SUCCESS" ]; then
                echo "    Bundle: ${GREEN}✓${NC}"
            else
                echo "    Bundle: ${RED}✗${NC}"
            fi
        fi
        
        # Show benchmark status
        local benchmark_result=$(cat "$RESULTS_DIR/benchmark_${version}" 2>/dev/null || echo "")
        local exit_code=$(cat "$RESULTS_DIR/exit_${version}" 2>/dev/null || echo "")
        if [ -n "$benchmark_result" ]; then
            if [ "$benchmark_result" = "PASSED" ]; then
                echo "    Benchmarks: ${GREEN}✓${NC}"
            else
                echo "    Benchmarks: ${RED}✗${NC} (exit code: ${exit_code})"
            fi
            extract_benchmark_summary "$version"
        fi
    done
    
    echo ""
    print_status "$BLUE" "Total: ${total} | Passed: ${GREEN}${passed}${NC} | Failed: ${RED}${failed}${NC} | Skipped: ${YELLOW}${skipped}${NC}"
    
    # Print log file locations
    echo ""
    print_status "$BLUE" "Detailed logs saved to: ${CURRENT_LOG_DIR}"
    for version in "${RUBY_VERSIONS[@]}"; do
        if [ -f "${CURRENT_LOG_DIR}/bundle_install_${version}.log" ]; then
            echo "  Bundle install (${version}): ${CURRENT_LOG_DIR}/bundle_install_${version}.log"
        fi
        if [ -f "${CURRENT_LOG_DIR}/benchmark_${version}.log" ]; then
            echo "  Benchmarks (${version}): ${CURRENT_LOG_DIR}/benchmark_${version}.log"
        fi
    done
    echo ""
    print_status "$BLUE" "All logs preserved in: ${CURRENT_LOG_DIR}"
    print_status "$BLUE" "Benchmark results also saved to: ${PROJECT_ROOT}/benchmarks/results/"
    
    # Exit with appropriate code
    if [ $failed -gt 0 ]; then
        exit 1
    elif [ $skipped -eq $total ]; then
        exit 2
    else
        exit 0
    fi
}

# Main execution
main() {
    print_status "$BLUE" "Decision Agent - Multi-Ruby Version Benchmark Runner"
    print_status "$BLUE" "=========================================="
    
    # Clean up old results
    rm -rf "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR"
    
    # Check prerequisites
    check_asdf
    
    # Benchmark each Ruby version
    for version in "${RUBY_VERSIONS[@]}"; do
        benchmark_ruby_version "$version"
    done
    
    # Print summary
    print_summary
    
    # Cleanup results directory
    rm -rf "$RESULTS_DIR"
}

# Run main function
main
