#!/bin/bash
# Convenience script to run benchmarks in Docker containers
# Usage: ./run_in_docker.sh [ruby_version] [benchmark_task]

set -e

# Default values
RUBY_VERSION="${1:-3.3}"
BENCHMARK_TASK="${2:-all}"

# Supported Ruby versions
SUPPORTED_VERSIONS=("3.0" "3.1" "3.2" "3.3")

# Available benchmark tasks
AVAILABLE_TASKS=("all" "basic" "threads" "evaluators" "operators" "memory" "batch" "regression" "baseline")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
  echo "Usage: $0 [ruby_version] [benchmark_task]"
  echo ""
  echo "Arguments:"
  echo "  ruby_version    Ruby version to use (default: 3.3)"
  echo "                  Supported: 3.0, 3.1, 3.2, 3.3"
  echo "  benchmark_task  Benchmark task to run (default: all)"
  echo "                  Available: all, basic, threads, evaluators, operators, memory, batch, regression, baseline"
  echo ""
  echo "Examples:"
  echo "  $0                    # Run all benchmarks with Ruby 3.3"
  echo "  $0 3.2                # Run all benchmarks with Ruby 3.2"
  echo "  $0 3.3 basic          # Run basic benchmark with Ruby 3.3"
  echo "  $0 3.1 regression     # Run regression test with Ruby 3.1"
  echo "  $0 3.0 baseline        # Update baseline with Ruby 3.0"
  exit 1
}

# Function to check if Ruby version is supported
is_supported_version() {
  local version=$1
  for v in "${SUPPORTED_VERSIONS[@]}"; do
    if [ "$v" == "$version" ]; then
      return 0
    fi
  done
  return 1
}

# Function to check if task is available
is_available_task() {
  local task=$1
  for t in "${AVAILABLE_TASKS[@]}"; do
    if [ "$t" == "$task" ]; then
      return 0
    fi
  done
  return 1
}

# Validate Ruby version
if ! is_supported_version "$RUBY_VERSION"; then
  echo -e "${RED}Error: Unsupported Ruby version: $RUBY_VERSION${NC}"
  echo -e "Supported versions: ${SUPPORTED_VERSIONS[*]}"
  usage
fi

# Validate benchmark task
if ! is_available_task "$BENCHMARK_TASK"; then
  echo -e "${RED}Error: Unknown benchmark task: $BENCHMARK_TASK${NC}"
  echo -e "Available tasks: ${AVAILABLE_TASKS[*]}"
  usage
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}Error: docker-compose is not installed or not in PATH${NC}"
  exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  echo -e "${RED}Error: Docker is not running${NC}"
  exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Check if docker-compose.yml exists
if [ ! -f "$COMPOSE_FILE" ]; then
  echo -e "${RED}Error: docker-compose.yml not found at $COMPOSE_FILE${NC}"
  exit 1
fi

# Service name based on Ruby version
SERVICE_NAME="benchmark-$RUBY_VERSION"

# Print configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Running Benchmarks in Docker${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Ruby Version:  ${GREEN}$RUBY_VERSION${NC}"
echo -e "Benchmark:     ${GREEN}benchmark:$BENCHMARK_TASK${NC}"
echo -e "Service:       ${GREEN}$SERVICE_NAME${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Build the Docker image if it doesn't exist or if --build flag is set
if [ "$3" == "--build" ] || ! docker-compose -f "$COMPOSE_FILE" ps "$SERVICE_NAME" &> /dev/null; then
  echo -e "${YELLOW}Building Docker image for Ruby $RUBY_VERSION...${NC}"
  docker-compose -f "$COMPOSE_FILE" build "$SERVICE_NAME"
  echo ""
fi

# Run the benchmark
echo -e "${YELLOW}Running benchmark:$BENCHMARK_TASK in Docker container...${NC}"
echo ""

# Change to the benchmarks directory to ensure relative paths work correctly
cd "$SCRIPT_DIR"

# Run the docker-compose command
if docker-compose -f "$COMPOSE_FILE" run --rm "$SERVICE_NAME" rake "benchmark:$BENCHMARK_TASK"; then
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Benchmark completed successfully!${NC}"
  echo -e "${GREEN}========================================${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}Benchmark failed!${NC}"
  echo -e "${RED}========================================${NC}"
  exit 1
fi

