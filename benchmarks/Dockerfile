ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy project files
COPY . .

# Set environment variables for consistent benchmarking
ENV RUBY_GC_HEAP_INIT_SLOTS=10000
ENV RUBY_GC_HEAP_FREE_SLOTS=5000
ENV RACK_ENV=production
ENV BENCHMARK_MODE=docker

# Default command
CMD ["rake", "benchmark:all"]

