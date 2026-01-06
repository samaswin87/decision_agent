require "csv"
require "json"
require_relative "errors"

module DecisionAgent
  module Simulation
    # Engine for replaying historical decisions and backtesting rule changes
    class ReplayEngine
      attr_reader :agent, :version_manager

      def initialize(agent:, version_manager: nil)
        @agent = agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Replay historical decisions with a specific rule version
      # @param historical_data [String, Array<Hash>] Path to CSV/JSON file or array of context hashes
      # @param rule_version [String, Integer, Hash, nil] Version ID, version hash, or nil to use current agent
      # @param compare_with [String, Integer, Hash, nil] Optional baseline version to compare against
      # @param options [Hash] Execution options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :progress_callback [Proc] Progress callback
      # @return [Hash] Replay results with comparison data
      def replay(historical_data:, rule_version: nil, compare_with: nil, options: {})
        contexts = load_historical_data(historical_data)
        options = {
          parallel: true,
          thread_count: 4,
          progress_callback: nil
        }.merge(options)

        # Build agent with specified version
        replay_agent = build_agent_from_version(rule_version) if rule_version
        replay_agent ||= @agent

        # Build baseline agent if comparison requested
        baseline_agent = build_agent_from_version(compare_with) if compare_with

        # Execute replay
        results = execute_replay(contexts, replay_agent, baseline_agent, options)

        # Build comparison report
        build_comparison_report(results, baseline_agent)
      end

      # Backtest a rule change against historical data
      # @param historical_data [String, Array<Hash>] Historical context data
      # @param proposed_version [String, Integer, Hash] Proposed rule version
      # @param baseline_version [String, Integer, Hash, nil] Baseline version (default: active version)
      # @param options [Hash] Execution options
      # @return [Hash] Backtest results with impact analysis
      def backtest(historical_data:, proposed_version:, baseline_version: nil, options: {})
        baseline_version ||= get_active_version_for_rule(proposed_version)
        replay(
          historical_data: historical_data,
          rule_version: proposed_version,
          compare_with: baseline_version,
          options: options
        )
      end

      private

      def load_historical_data(data)
        case data
        when String
          load_from_file(data)
        when Array
          data
        else
          raise InvalidHistoricalDataError, "Historical data must be a file path (String) or array of contexts"
        end
      end

      def load_from_file(file_path)
        case File.extname(file_path).downcase
        when ".csv"
          load_csv(file_path)
        when ".json"
          load_json(file_path)
        else
          raise InvalidHistoricalDataError, "Unsupported file format. Use CSV or JSON"
        end
      end

      def load_csv(file_path)
        contexts = []
        CSV.foreach(file_path, headers: true, header_converters: :symbol) do |row|
          contexts << row.to_h
        end
        contexts
      rescue StandardError => e
        raise InvalidHistoricalDataError, "Failed to load CSV: #{e.message}"
      end

      def load_json(file_path)
        content = File.read(file_path)
        data = JSON.parse(content, symbolize_names: true)
        data.is_a?(Array) ? data : [data]
      rescue StandardError => e
        raise InvalidHistoricalDataError, "Failed to load JSON: #{e.message}"
      end

      def build_agent_from_version(version)
        version_hash = resolve_version(version)
        evaluators = build_evaluators_from_version(version_hash)
        Agent.new(
          evaluators: evaluators,
          scoring_strategy: @agent.scoring_strategy,
          audit_adapter: Audit::NullAdapter.new
        )
      end

      def resolve_version(version)
        case version
        when String, Integer
          version_data = @version_manager.get_version(version_id: version)
          raise VersionComparisonError, "Version not found: #{version}" unless version_data
          version_data
        when Hash
          version
        else
          raise VersionComparisonError, "Invalid version format: #{version.class}"
        end
      end

      def build_evaluators_from_version(version)
        content = version[:content] || version["content"]
        return @agent.evaluators unless content

        if content.is_a?(Hash) && content[:evaluators]
          build_evaluators_from_config(content[:evaluators])
        elsif content.is_a?(Hash) && (content[:rules] || content["rules"])
          [Evaluators::JsonRuleEvaluator.new(rules_json: content)]
        else
          @agent.evaluators
        end
      end

      def build_evaluators_from_config(configs)
        Array(configs).map do |config|
          case config[:type] || config["type"]
          when "json_rule"
            Evaluators::JsonRuleEvaluator.new(rules_json: config[:rules] || config["rules"])
          when "dmn"
            model = config[:model] || config["model"]
            decision_id = config[:decision_id] || config["decision_id"]
            Evaluators::DmnEvaluator.new(model: model, decision_id: decision_id)
          else
            raise VersionComparisonError, "Unknown evaluator type: #{config[:type]}"
          end
        end
      end

      def get_active_version_for_rule(proposed_version)
        version_hash = resolve_version(proposed_version)
        rule_id = version_hash[:rule_id] || version_hash["rule_id"]
        return nil unless rule_id

        @version_manager.get_active_version(rule_id: rule_id)
      end

      def execute_replay(contexts, replay_agent, baseline_agent, options)
        results = []
        mutex = Mutex.new
        completed = 0
        total = contexts.size

        if options[:parallel] && contexts.size > 1
          execute_parallel(contexts, replay_agent, baseline_agent, options, mutex) do |result|
            mutex.synchronize do
              results << result
              completed += 1
              options[:progress_callback]&.call(
                completed: completed,
                total: total,
                percentage: (completed.to_f / total * 100).round(2)
              )
            end
          end
        else
          contexts.each_with_index do |context, index|
            result = execute_single_replay(context, replay_agent, baseline_agent)
            results << result
            completed = index + 1
            options[:progress_callback]&.call(
              completed: completed,
              total: total,
              percentage: (completed.to_f / total * 100).round(2)
            )
          end
        end

        results
      end

      def execute_parallel(contexts, replay_agent, baseline_agent, options, mutex)
        thread_count = [options[:thread_count], contexts.size].min
        queue = Queue.new
        contexts.each { |c| queue << c }

        threads = Array.new(thread_count) do
          Thread.new do
            loop do
              context = begin
                queue.pop(true)
              rescue StandardError
                nil
              end
              break unless context

              result = execute_single_replay(context, replay_agent, baseline_agent)
              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def execute_single_replay(context, replay_agent, baseline_agent)
        ctx = context.is_a?(Context) ? context : Context.new(context)

        replay_decision = replay_agent.decide(context: ctx)
        baseline_decision = baseline_agent&.decide(context: ctx)

        {
          context: ctx.to_h,
          replay_decision: replay_decision.decision,
          replay_confidence: replay_decision.confidence,
          baseline_decision: baseline_decision&.decision,
          baseline_confidence: baseline_decision&.confidence,
          changed: baseline_decision ? (replay_decision.decision != baseline_decision.decision) : false,
          confidence_delta: baseline_decision ? (replay_decision.confidence - baseline_decision.confidence) : nil
        }
      end

      def build_comparison_report(results, baseline_agent)
        total = results.size
        changed = results.count { |r| r[:changed] }
        unchanged = total - changed

        confidence_deltas = results.map { |r| r[:confidence_delta] }.compact
        avg_confidence_delta = confidence_deltas.any? ? confidence_deltas.sum / confidence_deltas.size : 0

        decision_distribution = results.group_by { |r| r[:replay_decision] }.transform_values(&:count)
        baseline_distribution = results.select { |r| r[:baseline_decision] }
                                      .group_by { |r| r[:baseline_decision] }
                                      .transform_values(&:count)

        {
          total_decisions: total,
          changed_decisions: changed,
          unchanged_decisions: unchanged,
          change_rate: total > 0 ? (changed.to_f / total) : 0,
          average_confidence_delta: avg_confidence_delta,
          decision_distribution: decision_distribution,
          baseline_distribution: baseline_distribution,
          results: results,
          has_baseline: !baseline_agent.nil?
        }
      end
    end
  end
end

