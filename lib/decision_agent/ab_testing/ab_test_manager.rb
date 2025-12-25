require "monitor"

module DecisionAgent
  module ABTesting
    # Manages A/B tests and provides high-level orchestration
    class ABTestManager
      include MonitorMixin

      attr_reader :storage_adapter, :version_manager

      # @param storage_adapter [Storage::Adapter] Storage adapter for persistence
      # @param version_manager [Versioning::VersionManager] Version manager for rule versions
      def initialize(storage_adapter: nil, version_manager: nil)
        super()
        @storage_adapter = storage_adapter || default_storage_adapter
        @version_manager = version_manager || Versioning::VersionManager.new
        @active_tests_cache = {}
      end

      # Create a new A/B test
      # @param name [String] Name of the test
      # @param champion_version_id [String, Integer] ID of the champion version
      # @param challenger_version_id [String, Integer] ID of the challenger version
      # @param traffic_split [Hash] Traffic distribution
      # @param start_date [Time, nil] When to start the test
      # @param end_date [Time, nil] When to end the test
      # @return [ABTest] The created test
      def create_test(name:, champion_version_id:, challenger_version_id:, traffic_split: { champion: 90, challenger: 10 }, start_date: nil, end_date: nil)
        synchronize do
          # Validate that both versions exist
          validate_version_exists!(champion_version_id, "champion")
          validate_version_exists!(challenger_version_id, "challenger")

          test = ABTest.new(
            name: name,
            champion_version_id: champion_version_id,
            challenger_version_id: challenger_version_id,
            traffic_split: traffic_split,
            start_date: start_date || Time.now.utc,
            end_date: end_date,
            status: start_date && start_date > Time.now.utc ? "scheduled" : "running"
          )

          saved_test = @storage_adapter.save_test(test)
          invalidate_cache!
          saved_test
        end
      end

      # Get an A/B test by ID
      # @param test_id [String, Integer] The test ID
      # @return [ABTest, nil] The test or nil if not found
      def get_test(test_id)
        @storage_adapter.get_test(test_id)
      end

      # Get all active A/B tests
      # @return [Array<ABTest>] Array of active tests
      def active_tests
        synchronize do
          return @active_tests_cache[:tests] if cache_valid?

          tests = @storage_adapter.list_tests(status: "running")
          @active_tests_cache = { tests: tests, timestamp: Time.now.utc }
          tests
        end
      end

      # Assign a variant for a request
      # @param test_id [String, Integer] The A/B test ID
      # @param user_id [String, nil] Optional user identifier for consistent assignment
      # @return [Hash] Assignment details { test_id:, variant:, version_id: }
      def assign_variant(test_id:, user_id: nil)
        test = get_test(test_id)
        raise TestNotFoundError, "Test not found: #{test_id}" unless test

        variant = test.assign_variant(user_id: user_id)
        version_id = test.version_for_variant(variant)

        assignment = ABTestAssignment.new(
          ab_test_id: test_id,
          user_id: user_id,
          variant: variant,
          version_id: version_id
        )

        saved_assignment = @storage_adapter.save_assignment(assignment)

        {
          test_id: test_id,
          variant: variant,
          version_id: version_id,
          assignment_id: saved_assignment.id
        }
      end

      # Record the decision result for an assignment
      # @param assignment_id [String, Integer] The assignment ID
      # @param decision [String] The decision result
      # @param confidence [Float] The confidence score
      def record_decision(assignment_id:, decision:, confidence:)
        @storage_adapter.update_assignment(assignment_id, decision_result: decision, confidence: confidence)
      end

      # Get results comparison for an A/B test
      # @param test_id [String, Integer] The test ID
      # @return [Hash] Comparison statistics
      def get_results(test_id)
        test = get_test(test_id)
        raise TestNotFoundError, "Test not found: #{test_id}" unless test

        assignments = @storage_adapter.get_assignments(test_id)

        champion_assignments = assignments.select { |a| a.variant == :champion }
        challenger_assignments = assignments.select { |a| a.variant == :challenger }

        {
          test: test.to_h,
          champion: calculate_variant_stats(champion_assignments, "Champion"),
          challenger: calculate_variant_stats(challenger_assignments, "Challenger"),
          comparison: compare_variants(champion_assignments, challenger_assignments),
          total_assignments: assignments.size,
          timestamp: Time.now.utc
        }
      end

      # Start a scheduled test
      # @param test_id [String, Integer] The test ID
      def start_test(test_id)
        synchronize do
          test = get_test(test_id)
          raise TestNotFoundError, "Test not found: #{test_id}" unless test

          test.start!
          @storage_adapter.update_test(test_id, status: "running", start_date: test.start_date)
          invalidate_cache!
        end
      end

      # Complete a running test
      # @param test_id [String, Integer] The test ID
      def complete_test(test_id)
        synchronize do
          test = get_test(test_id)
          raise TestNotFoundError, "Test not found: #{test_id}" unless test

          test.complete!
          @storage_adapter.update_test(test_id, status: "completed", end_date: test.end_date)
          invalidate_cache!
        end
      end

      # Cancel a test
      # @param test_id [String, Integer] The test ID
      def cancel_test(test_id)
        synchronize do
          test = get_test(test_id)
          raise TestNotFoundError, "Test not found: #{test_id}" unless test

          test.cancel!
          @storage_adapter.update_test(test_id, status: "cancelled")
          invalidate_cache!
        end
      end

      # List all tests with optional filtering
      # @param status [String, nil] Filter by status
      # @param limit [Integer, nil] Limit results
      # @return [Array<ABTest>] Array of tests
      def list_tests(status: nil, limit: nil)
        @storage_adapter.list_tests(status: status, limit: limit)
      end

      private

      def default_storage_adapter
        # Use in-memory adapter by default
        require_relative "storage/memory_adapter"
        Storage::MemoryAdapter.new
      end

      def validate_version_exists!(version_id, label)
        version = @version_manager.get_version(version_id: version_id)
        return if version

        raise VersionNotFoundError, "#{label.capitalize} version not found: #{version_id}"
      end

      def cache_valid?
        return false unless @active_tests_cache[:timestamp]

        # Cache is valid for 60 seconds
        Time.now.utc - @active_tests_cache[:timestamp] < 60
      end

      def invalidate_cache!
        @active_tests_cache = {}
      end

      def calculate_variant_stats(assignments, label)
        with_decisions = assignments.select { |a| a.decision_result }

        return {
          label: label,
          total_assignments: assignments.size,
          decisions_recorded: 0,
          avg_confidence: nil,
          decision_distribution: {}
        } if with_decisions.empty?

        confidences = with_decisions.map(&:confidence)
        decision_counts = with_decisions.group_by(&:decision_result).transform_values(&:size)

        {
          label: label,
          total_assignments: assignments.size,
          decisions_recorded: with_decisions.size,
          avg_confidence: (confidences.sum / confidences.size.to_f).round(4),
          min_confidence: confidences.min&.round(4),
          max_confidence: confidences.max&.round(4),
          decision_distribution: decision_counts
        }
      end

      def compare_variants(champion_assignments, challenger_assignments)
        champion_with_decisions = champion_assignments.select { |a| a.decision_result }
        challenger_with_decisions = challenger_assignments.select { |a| a.decision_result }

        return { statistical_significance: "insufficient_data" } if champion_with_decisions.empty? || challenger_with_decisions.empty?

        champion_confidences = champion_with_decisions.map(&:confidence)
        challenger_confidences = challenger_with_decisions.map(&:confidence)

        champion_avg = champion_confidences.sum / champion_confidences.size.to_f
        challenger_avg = challenger_confidences.sum / challenger_confidences.size.to_f

        improvement = ((challenger_avg - champion_avg) / champion_avg * 100).round(2)

        # Calculate statistical significance using Welch's t-test approximation
        sig_result = calculate_statistical_significance(champion_confidences, challenger_confidences)

        {
          champion_avg_confidence: champion_avg.round(4),
          challenger_avg_confidence: challenger_avg.round(4),
          improvement_percentage: improvement,
          winner: determine_winner(champion_avg, challenger_avg, sig_result[:significant]),
          statistical_significance: sig_result[:significant] ? "significant" : "not_significant",
          confidence_level: sig_result[:confidence_level],
          recommendation: generate_recommendation(improvement, sig_result[:significant])
        }
      end

      def calculate_statistical_significance(sample1, sample2)
        n1 = sample1.size
        n2 = sample2.size

        return { significant: false, confidence_level: 0 } if n1 < 30 || n2 < 30

        mean1 = sample1.sum / n1.to_f
        mean2 = sample2.sum / n2.to_f

        var1 = sample1.map { |x| (x - mean1)**2 }.sum / (n1 - 1).to_f
        var2 = sample2.map { |x| (x - mean2)**2 }.sum / (n2 - 1).to_f

        # Welch's t-statistic
        t_stat = (mean1 - mean2) / Math.sqrt((var1 / n1) + (var2 / n2))

        # Simplified p-value approximation (for demonstration)
        # In production, use a proper statistical library
        t_stat_abs = t_stat.abs

        confidence_level = if t_stat_abs > 2.576
                             0.99 # 99% confidence
                           elsif t_stat_abs > 1.96
                             0.95 # 95% confidence
                           elsif t_stat_abs > 1.645
                             0.90 # 90% confidence
                           else
                             0.0
                           end

        {
          significant: confidence_level >= 0.95,
          confidence_level: confidence_level,
          t_statistic: t_stat.round(4)
        }
      end

      def determine_winner(champion_avg, challenger_avg, significant)
        return "inconclusive" unless significant

        challenger_avg > champion_avg ? "challenger" : "champion"
      end

      def generate_recommendation(improvement, significant)
        if !significant
          "Continue testing - not enough data for statistical significance"
        elsif improvement > 5
          "Strong evidence to promote challenger"
        elsif improvement > 0
          "Moderate evidence to promote challenger"
        elsif improvement > -5
          "Results are similar - consider other factors"
        else
          "Keep champion - challenger performs worse"
        end
      end
    end

    # Custom errors
    class TestNotFoundError < StandardError; end
    class VersionNotFoundError < StandardError; end
  end
end
