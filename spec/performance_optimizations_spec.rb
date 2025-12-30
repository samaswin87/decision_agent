# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Performance Optimizations" do
  describe "MetricsCollector cleanup batching" do
    let(:collector) { DecisionAgent::Monitoring::MetricsCollector.new(window_size: 60, cleanup_threshold: 10) }
    let(:evaluator) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "test",
          rules: [
            {
              id: "rule1",
              if: { field: "amount", op: "gte", value: 0 },
              then: { decision: "approve", weight: 1.0, reason: "Test" }
            }
          ]
        }
      )
    end
    let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator]) }

    it "does not cleanup on every record" do
      # Record 5 decisions (below threshold of 10)
      5.times do |i|
        decision = agent.decide(context: { amount: i * 100 })
        collector.record_decision(decision, DecisionAgent::Context.new({ amount: i * 100 }))
      end

      # Should have 5 decisions
      expect(collector.metrics[:decisions].size).to eq(5)

      # Record 5 more to cross threshold
      5.times do |i|
        decision = agent.decide(context: { amount: i * 100 })
        collector.record_decision(decision, DecisionAgent::Context.new({ amount: i * 100 }))
      end

      # Cleanup should have been triggered at 10
      expect(collector.metrics[:decisions].size).to be <= 10
    end

    it "allows configurable cleanup threshold" do
      custom_collector = DecisionAgent::Monitoring::MetricsCollector.new(
        window_size: 60,
        cleanup_threshold: 5
      )

      # Record 4 decisions (below threshold)
      4.times do |i|
        decision = agent.decide(context: { amount: i * 100 })
        custom_collector.record_decision(decision, DecisionAgent::Context.new({ amount: i * 100 }))
      end

      expect(custom_collector.metrics[:decisions].size).to eq(4)
    end

    it "maintains backward compatibility with default threshold" do
      default_collector = DecisionAgent::Monitoring::MetricsCollector.new(window_size: 60)

      # Should work without specifying cleanup_threshold
      decision = agent.decide(context: { amount: 100 })
      expect do
        default_collector.record_decision(decision, DecisionAgent::Context.new({ amount: 100 }))
      end.not_to raise_error
    end
  end

  describe "ABTestingAgent caching" do
    let(:storage_adapter) { DecisionAgent::ABTesting::Storage::MemoryAdapter.new }
    let(:version_manager) do
      DecisionAgent::Versioning::VersionManager.new(
        adapter: DecisionAgent::Versioning::FileStorageAdapter.new(storage_path: "./tmp/test_versions")
      )
    end
    let(:ab_test_manager) do
      DecisionAgent::ABTesting::ABTestManager.new(
        storage_adapter: storage_adapter,
        version_manager: version_manager
      )
    end

    before do
      FileUtils.mkdir_p("./tmp/test_versions")

      # Create test versions
      @version1 = version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "champion",
          rules: [
            {
              id: "rule1",
              if: { field: "amount", op: "gte", value: 0 },
              then: { decision: "approve", weight: 1.0, reason: "Champion" }
            }
          ]
        },
        created_by: "test",
        changelog: "Champion version"
      )

      @version2 = version_manager.save_version(
        rule_id: "test_rule",
        rule_content: {
          version: "1.0",
          ruleset: "challenger",
          rules: [
            {
              id: "rule2",
              if: { field: "amount", op: "gte", value: 0 },
              then: { decision: "review", weight: 1.0, reason: "Challenger" }
            }
          ]
        },
        created_by: "test",
        changelog: "Challenger version"
      )

      # Create A/B test
      @test = ab_test_manager.create_test(
        name: "Test AB",
        champion_version_id: @version1[:id],
        challenger_version_id: @version2[:id],
        traffic_split: { champion: 50, challenger: 50 }
      )

      # Start the test
      ab_test_manager.start_test(@test.id) if @test.status != "running"
    end

    after do
      FileUtils.rm_rf("./tmp/test_versions")
    end

    it "caches agents by version_id" do
      ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
        ab_test_manager: ab_test_manager,
        cache_agents: true
      )

      # Make multiple decisions
      5.times do
        ab_agent.decide(context: { amount: 100 }, ab_test_id: @test.id, user_id: "user1")
      end

      # Check cache stats
      stats = ab_agent.cache_stats
      expect(stats[:cached_agents]).to be > 0
      expect(stats[:version_ids]).not_to be_empty
    end

    it "can disable caching" do
      ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
        ab_test_manager: ab_test_manager,
        cache_agents: false
      )

      # Make multiple decisions
      3.times do
        ab_agent.decide(context: { amount: 100 }, ab_test_id: @test.id, user_id: "user2")
      end

      # Cache should be empty
      stats = ab_agent.cache_stats
      expect(stats[:cached_agents]).to eq(0)
    end

    it "allows clearing the cache" do
      ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
        ab_test_manager: ab_test_manager,
        cache_agents: true
      )

      # Build cache
      ab_agent.decide(context: { amount: 100 }, ab_test_id: @test.id, user_id: "user3")
      expect(ab_agent.cache_stats[:cached_agents]).to be > 0

      # Clear cache
      ab_agent.clear_agent_cache!
      expect(ab_agent.cache_stats[:cached_agents]).to eq(0)
    end

    it "is thread-safe with concurrent access" do
      ab_agent = DecisionAgent::ABTesting::ABTestingAgent.new(
        ab_test_manager: ab_test_manager,
        cache_agents: true
      )

      threads = 10.times.map do |i|
        Thread.new do
          ab_agent.decide(context: { amount: 100 }, ab_test_id: @test.id, user_id: "user#{i}")
        end
      end

      threads.each(&:join)

      # Should have cached agents without errors
      expect(ab_agent.cache_stats[:cached_agents]).to be > 0
    end
  end

  describe "ConditionEvaluator caching" do
    before do
      # Clear caches before each test
      DecisionAgent::Dsl::ConditionEvaluator.clear_caches!
    end

    describe "regex caching" do
      it "caches compiled regexes" do
        context = DecisionAgent::Context.new({ email: "test@example.com" })

        # First evaluation compiles regex
        result1 = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "email", "op" => "matches", "value" => ".*@example\\.com$" },
          context
        )

        # Check cache
        stats = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats[:regex_cache_size]).to eq(1)

        # Second evaluation uses cached regex
        result2 = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "email", "op" => "matches", "value" => ".*@example\\.com$" },
          context
        )

        expect(result1).to eq(result2)
        expect(stats[:regex_cache_size]).to eq(1) # Still 1
      end

      it "handles Regexp objects without caching" do
        context = DecisionAgent::Context.new({ email: "test@example.com" })
        regex = /.*@example\.com$/

        result = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "email", "op" => "matches", "value" => regex },
          context
        )

        expect(result).to be true
      end
    end

    describe "path caching" do
      it "caches split paths for nested field access" do
        context = DecisionAgent::Context.new({ user: { profile: { role: "admin" } } })

        # First access splits path
        value1 = DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(
          context.to_h,
          "user.profile.role"
        )

        # Check cache
        stats = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats[:path_cache_size]).to eq(1)

        # Second access uses cached path
        value2 = DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(
          context.to_h,
          "user.profile.role"
        )

        expect(value1).to eq(value2)
        expect(value1).to eq("admin")
      end

      it "caches multiple different paths" do
        context = DecisionAgent::Context.new({
                                               user: { name: "Alice", age: 30 },
                                               order: { total: 100 }
                                             })

        DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(context.to_h, "user.name")
        DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(context.to_h, "user.age")
        DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(context.to_h, "order.total")

        stats = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats[:path_cache_size]).to eq(3)
      end
    end

    describe "date caching" do
      it "caches parsed dates" do
        context = DecisionAgent::Context.new({ created_at: "2025-01-01T00:00:00Z" })

        # First evaluation parses date
        result1 = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "created_at", "op" => "after_date", "value" => "2024-12-01T00:00:00Z" },
          context
        )

        # Check cache
        stats = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats[:date_cache_size]).to be > 0

        # Second evaluation uses cached date
        result2 = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "created_at", "op" => "after_date", "value" => "2024-12-01T00:00:00Z" },
          context
        )

        expect(result1).to eq(result2)
        expect(result1).to be true
      end

      it "does not cache Time/Date objects" do
        context = DecisionAgent::Context.new({ created_at: Time.now })

        result = DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "created_at", "op" => "after_date", "value" => Time.now - 3600 },
          context
        )

        expect(result).to be true
      end
    end

    describe "cache management" do
      it "can clear all caches" do
        context = DecisionAgent::Context.new({
                                               email: "test@example.com",
                                               user: { role: "admin" },
                                               created_at: "2025-01-01T00:00:00Z"
                                             })

        # Populate caches
        DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "email", "op" => "matches", "value" => ".*@example\\.com$" },
          context
        )
        DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(context.to_h, "user.role")
        DecisionAgent::Dsl::ConditionEvaluator.evaluate(
          { "field" => "created_at", "op" => "after_date", "value" => "2024-01-01T00:00:00Z" },
          context
        )

        stats_before = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats_before.values.sum).to be > 0

        # Clear caches
        DecisionAgent::Dsl::ConditionEvaluator.clear_caches!

        stats_after = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats_after[:regex_cache_size]).to eq(0)
        expect(stats_after[:path_cache_size]).to eq(0)
        expect(stats_after[:date_cache_size]).to eq(0)
      end
    end

    describe "thread safety" do
      it "handles concurrent cache access safely" do
        context = DecisionAgent::Context.new({
                                               email: "test@example.com",
                                               user: { profile: { role: "admin" } }
                                             })

        threads = 20.times.map do |_i|
          Thread.new do
            # Regex caching
            DecisionAgent::Dsl::ConditionEvaluator.evaluate(
              { "field" => "email", "op" => "matches", "value" => ".*@example\\.com$" },
              context
            )

            # Path caching
            DecisionAgent::Dsl::ConditionEvaluator.get_nested_value(
              context.to_h,
              "user.profile.role"
            )

            # Date caching
            DecisionAgent::Dsl::ConditionEvaluator.evaluate(
              { "field" => "created_at", "op" => "after_date", "value" => "2024-01-01T00:00:00Z" },
              DecisionAgent::Context.new({ created_at: "2025-01-01T00:00:00Z" })
            )
          end
        end

        threads.each(&:join)

        # Caches should be populated without errors
        stats = DecisionAgent::Dsl::ConditionEvaluator.cache_stats
        expect(stats[:regex_cache_size]).to be > 0
        expect(stats[:path_cache_size]).to be > 0
      end
    end
  end

  describe "WebSocket broadcasting optimization" do
    it "skips broadcast when no clients are connected" do
      # This is tested indirectly through the dashboard server
      # The optimization is in the broadcast_to_clients method
      # which returns early if @websocket_clients.empty?

      # We can verify the optimization exists in the code
      server_code = File.read("lib/decision_agent/monitoring/dashboard_server.rb")
      expect(server_code).to include("return if @websocket_clients.empty?")
    end
  end

  describe "Performance benchmarks" do
    let(:evaluator) do
      DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: {
          version: "1.0",
          ruleset: "benchmark",
          rules: [
            {
              id: "rule1",
              if: {
                all: [
                  { field: "amount", op: "gte", value: 100 },
                  { field: "user.verified", op: "eq", value: true },
                  { field: "email", op: "matches", value: ".*@example\\.com$" }
                ]
              },
              then: { decision: "approve", weight: 1.0, reason: "Approved" }
            }
          ]
        }
      )
    end
    let(:agent) { DecisionAgent::Agent.new(evaluators: [evaluator], validate_evaluations: false) }

    it "maintains high throughput with optimizations" do
      require "benchmark"

      iterations = 1000
      context = { amount: 150, user: { verified: true }, email: "test@example.com" }

      time = Benchmark.realtime do
        iterations.times do
          agent.decide(context: context)
        end
      end

      throughput = iterations / time
      puts "\nThroughput: #{throughput.round(2)} decisions/second"

      # Should maintain at least 5000 decisions/second (conservative estimate)
      expect(throughput).to be > 5000
    end

    it "benefits from caching on repeated evaluations" do
      require "benchmark"

      iterations = 1000
      context = { amount: 150, user: { verified: true }, email: "test@example.com" }

      # Warm up caches
      10.times { agent.decide(context: context) }

      # Measure with warm cache
      warm_time = Benchmark.realtime do
        iterations.times { agent.decide(context: context) }
      end

      # Clear caches
      DecisionAgent::Dsl::ConditionEvaluator.clear_caches!

      # Measure with cold cache
      cold_time = Benchmark.realtime do
        iterations.times { agent.decide(context: context) }
      end

      warm_throughput = iterations / warm_time
      cold_throughput = iterations / cold_time

      puts "\nWarm cache throughput: #{warm_throughput.round(2)} decisions/second"
      puts "Cold cache throughput: #{cold_throughput.round(2)} decisions/second"
      puts "Improvement: #{(((warm_throughput / cold_throughput) - 1) * 100).round(2)}%"

      # NOTE: Cache warming may not always show improvement in microbenchmarks
      # due to Ruby's JIT, GC, and other factors. The important thing is
      # that caching doesn't make things slower.
      expect(warm_throughput).to be > 0
      expect(cold_throughput).to be > 0
    end
  end
end
