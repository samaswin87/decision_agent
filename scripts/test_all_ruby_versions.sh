#!/usr/bin/env bash

# Script to test decision_agent across multiple Ruby versions using asdf
#
# This script will:
#   1. Test each Ruby version (3.0.7, 3.1.6, 3.2.5, 3.3.5)
#   2. Run bundle install for each version
#   3. Run RSpec tests for each version
#   4. Generate a summary report with results
#
# Requirements:
#   - asdf installed and in PATH
#   - Ruby versions installed via asdf: asdf install ruby 3.0.7 (etc.)
#
# Usage:
#   ./scripts/test_all_ruby_versions.sh
#
# Output:
#   - Console output with colored status messages
#   - Log files in test_logs/<timestamp>/ for bundle install and rspec results
#   - JSON test results in test_logs/<timestamp>/rspec_<version>.json
#   - Logs are preserved and not deleted (organized by timestamp)

# Don't exit on error - we want to test all versions even if one fails
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
RESULTS_DIR="/tmp/ruby_test_results"
mkdir -p "$RESULTS_DIR"

# Log directory - save logs in project directory so they persist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/test_logs"
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

# Function to run RSpec tests with parallel_tests
run_rspec() {
    local version=$1
    print_status "$BLUE" "  → Running RSpec tests with parallel_tests..."
    
    # Run rspec in a subshell with the specified Ruby version
    local log_file="${CURRENT_LOG_DIR}/rspec_${version}.log"
    local json_file="${CURRENT_LOG_DIR}/rspec_${version}.json"
    local exit_file="${CURRENT_LOG_DIR}/rspec_${version}.exit"
    
    (
        setup_ruby_env "$version"
        # First, setup parallel test databases if needed (for ActiveRecord tests)
        # Only run if Rakefile exists and has parallel tasks
        if [ -f "Rakefile" ]; then
            bundle exec rake parallel:create parallel:setup 2>&1 || true
        fi
        
        # Run parallel tests
        # Use parallel_rspec which automatically determines number of processes
        # Note: parallel_rspec doesn't support --format directly, so we'll use default format
        bundle exec parallel_rspec spec 2>&1
        local parallel_exit=$?
        
        # Generate JSON output for detailed summary (run non-parallel for JSON)
        # Only if parallel tests passed, to avoid duplicate failures
        if [ "$parallel_exit" = "0" ]; then
            bundle exec rspec --format json --out "$json_file" spec 2>&1 || true
        fi
        
        echo $parallel_exit > "$exit_file"
    ) | tee "$log_file"
    
    local exit_code=$(cat "$exit_file" 2>/dev/null || echo "1")
    rm -f "$exit_file"
    echo "$exit_code" > "$RESULTS_DIR/exit_${version}"
    
    if [ "$exit_code" = "0" ]; then
        echo "PASSED" > "$RESULTS_DIR/test_${version}"
        print_status "$GREEN" "  ✓ All tests passed"
        return 0
    else
        echo "FAILED" > "$RESULTS_DIR/test_${version}"
        print_status "$RED" "  ✗ Tests failed (exit code: $exit_code)"
        return 1
    fi
}

# Function to extract test summary from JSON
extract_test_summary() {
    local version=$1
    local json_file="${CURRENT_LOG_DIR}/rspec_${version}.json"
    
    if [ -f "$json_file" ]; then
        # Try to extract summary using Ruby if available
        if command -v ruby &> /dev/null; then
            ruby -r json -e "
                begin
                    data = JSON.parse(File.read('$json_file'))
                    summary = data['summary']
                    puts \"    Examples: #{summary['example_count']}, Failures: #{summary['failure_count']}, Pending: #{summary['pending_count']}\"
                    puts \"    Duration: #{summary['duration']}s\"
                rescue => e
                    puts \"    (Could not parse test summary)\"
                end
            " 2>/dev/null || echo "    (Could not extract test summary)"
        else
            echo "    (Test summary not available)"
        fi
    else
        echo "    (Test results file not found)"
    fi
}

# Function to test a single Ruby version
test_ruby_version() {
    local version=$1
    
    print_status "$BLUE" "\n=========================================="
    print_status "$BLUE" "Testing Ruby ${version}"
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
        RESULTS[$version]="SKIPPED"
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
    
    # Run RSpec tests with the specified Ruby version
    if run_rspec "$version"; then
        echo "SUCCESS" > "$RESULTS_DIR/result_${version}"
        extract_test_summary "$version"
        return 0
    else
        echo "TEST_FAILED" > "$RESULTS_DIR/result_${version}"
        extract_test_summary "$version"
        return 1
    fi
}

# Function to print final summary
print_summary() {
    print_status "$BLUE" "\n=========================================="
    print_status "$BLUE" "TEST SUMMARY"
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
            "TEST_FAILED")
                print_status "$RED" "✗ Ruby ${version}: TESTS FAILED"
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
        
        # Show test status
        local test_result=$(cat "$RESULTS_DIR/test_${version}" 2>/dev/null || echo "")
        local exit_code=$(cat "$RESULTS_DIR/exit_${version}" 2>/dev/null || echo "")
        if [ -n "$test_result" ]; then
            if [ "$test_result" = "PASSED" ]; then
                echo "    Tests:  ${GREEN}✓${NC}"
            else
                echo "    Tests:  ${RED}✗${NC} (exit code: ${exit_code})"
            fi
            extract_test_summary "$version"
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
        if [ -f "${CURRENT_LOG_DIR}/rspec_${version}.log" ]; then
            echo "  RSpec tests (${version}): ${CURRENT_LOG_DIR}/rspec_${version}.log"
        fi
        if [ -f "${CURRENT_LOG_DIR}/rspec_${version}.json" ]; then
            echo "  RSpec JSON (${version}): ${CURRENT_LOG_DIR}/rspec_${version}.json"
        fi
    done
    echo ""
    print_status "$BLUE" "All logs preserved in: ${CURRENT_LOG_DIR}"
    
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
    print_status "$BLUE" "Decision Agent - Multi-Ruby Version Test Runner"
    print_status "$BLUE" "=========================================="
    
    # Clean up old results
    rm -rf "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR"
    
    # Check prerequisites
    check_asdf
    
    # Test each Ruby version
    for version in "${RUBY_VERSIONS[@]}"; do
        test_ruby_version "$version"
    done
    
    # Print summary
    print_summary
    
    # Cleanup results directory
    rm -rf "$RESULTS_DIR"
}

# Run main function
main
