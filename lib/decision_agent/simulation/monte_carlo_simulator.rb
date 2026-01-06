require_relative "errors"

module DecisionAgent
  module Simulation
    # Monte Carlo simulator for probabilistic decision outcomes
    #
    # Allows you to model input variables with probability distributions
    # and run simulations to understand decision outcome probabilities.
    #
    # @example
    #   simulator = MonteCarloSimulator.new(agent: agent)
    #
    #   # Define probabilistic inputs
    #   distributions = {
    #     credit_score: { type: :normal, mean: 650, stddev: 50 },
    #     amount: { type: :uniform, min: 50_000, max: 200_000 }
    #   }
    #
    #   # Run simulation
    #   results = simulator.simulate(
    #     distributions: distributions,
    #     iterations: 10_000,
    #     base_context: { name: "John Doe" }
    #   )
    #
    #   puts "Decision probabilities: #{results[:decision_probabilities]}"
    #   puts "Average confidence: #{results[:average_confidence]}"
    # rubocop:disable Metrics/ClassLength
    class MonteCarloSimulator
      attr_reader :agent, :version_manager

      def initialize(agent:, version_manager: nil)
        @agent = agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Run Monte Carlo simulation with probabilistic input distributions
      #
      # @param distributions [Hash] Hash of field_name => distribution_config
      #   Distribution configs support:
      #   - { type: :normal, mean: Float, stddev: Float } - Normal distribution
      #   - { type: :uniform, min: Numeric, max: Numeric } - Uniform distribution
      #   - { type: :lognormal, mean: Float, stddev: Float } - Log-normal distribution
      #   - { type: :exponential, lambda: Float } - Exponential distribution
      #   - { type: :discrete, values: Array, probabilities: Array } - Discrete distribution
      #   - { type: :triangular, min: Numeric, mode: Numeric, max: Numeric } - Triangular distribution
      # @param iterations [Integer] Number of Monte Carlo iterations (default: 10_000)
      # @param base_context [Hash] Base context values that are fixed (not probabilistic)
      # @param rule_version [String, Integer, Hash, nil] Optional rule version to use
      # @param options [Hash] Simulation options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :seed [Integer] Random seed for reproducibility (default: nil)
      #   - :confidence_level [Float] Confidence level for intervals (default: 0.95)
      # @return [Hash] Simulation results with decision probabilities and statistics
      def simulate(distributions:, iterations: 10_000, base_context: {}, rule_version: nil, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          seed: nil,
          confidence_level: 0.95
        }.merge(options)

        # Set random seed for reproducibility
        srand(options[:seed]) if options[:seed]

        # Validate distributions
        validate_distributions!(distributions)

        # Build agent from version if specified
        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        # Run Monte Carlo iterations
        results = run_iterations(
          distributions: distributions,
          base_context: base_context,
          iterations: iterations,
          agent: analysis_agent,
          options: options
        )

        # Calculate statistics (pass requested iterations count)
        calculate_statistics(results, options[:confidence_level], requested_iterations: iterations)
      end

      # Run sensitivity analysis using Monte Carlo simulation
      # Varies one distribution parameter at a time to see its impact
      #
      # @param base_distributions [Hash] Base probabilistic input distributions
      # @param sensitivity_params [Hash] Hash of field => parameter variations
      #   Example: { credit_score: { mean: [600, 650, 700], stddev: [40, 50, 60] } }
      # @param iterations [Integer] Number of iterations per sensitivity test
      # @param base_context [Hash] Base context values
      # @param options [Hash] Simulation options
      # @return [Hash] Sensitivity analysis results
      def sensitivity_analysis(
        base_distributions:,
        sensitivity_params:,
        iterations: 5_000,
        base_context: {},
        options: {}
      )
        options = {
          parallel: true,
          thread_count: 4,
          seed: nil,
          confidence_level: 0.95
        }.merge(options)

        srand(options[:seed]) if options[:seed]

        sensitivity_results = analyze_sensitivity_params(
          base_distributions, sensitivity_params, iterations, base_context, options
        )

        {
          sensitivity_results: sensitivity_results,
          base_distributions: base_distributions,
          iterations_per_test: iterations
        }
      end

      def analyze_sensitivity_params(base_distributions, sensitivity_params, iterations, base_context, options)
        sensitivity_params.each_with_object({}) do |(field, param_variations), results|
          results[field] = analyze_field_sensitivity(
            base_distributions, field, param_variations, iterations, base_context, options
          )
        end
      end

      def analyze_field_sensitivity(base_distributions, field, param_variations, iterations, base_context, options)
        param_variations.each_with_object({}) do |(param_name, param_values), field_results|
          config = {
            base_distributions: base_distributions,
            field: field,
            param_name: param_name,
            param_values: param_values,
            iterations: iterations,
            base_context: base_context,
            options: options
          }
          param_results = run_parameter_variations(config)
          field_results[param_name] = build_parameter_result(param_name, param_values, param_results)
        end
      end

      def run_parameter_variations(config)
        config[:param_values].map do |param_value|
          modified_distributions = create_modified_distribution(
            config[:base_distributions], config[:field], config[:param_name], param_value
          )
          result = simulate(
            distributions: modified_distributions,
            iterations: config[:iterations],
            base_context: config[:base_context],
            options: config[:options].merge(parallel: false)
          )
          build_param_result(param_value, result)
        end
      end

      def create_modified_distribution(base_distributions, field, param_name, param_value)
        modified = base_distributions.dup
        modified[field] = modified[field].dup
        modified[field][param_name] = param_value
        modified
      end

      def build_param_result(param_value, result)
        {
          param_value: param_value,
          decision_probabilities: result[:decision_probabilities],
          average_confidence: result[:average_confidence],
          confidence_intervals: result[:confidence_intervals]
        }
      end

      def build_parameter_result(param_name, param_values, param_results)
        {
          parameter: param_name,
          values_tested: param_values,
          results: param_results,
          impact_analysis: analyze_parameter_impact(param_results)
        }
      end

      private

      def validate_distributions!(distributions)
        distributions.each do |field, config|
          raise ArgumentError, "Distribution config for #{field} must be a Hash" unless config.is_a?(Hash)
          raise ArgumentError, "Distribution config for #{field} must include :type" unless config[:type] || config["type"]

          type = config[:type] || config["type"]
          validate_distribution_type!(field, type, config)
        end
      end

      def validate_distribution_type!(field, type, config)
        case type.to_sym
        when :normal
          validate_normal_distribution(field, config)
        when :uniform
          validate_uniform_distribution(field, config)
        when :lognormal
          validate_lognormal_distribution(field, config)
        when :exponential
          validate_exponential_distribution(field, config)
        when :discrete
          validate_discrete_distribution(field, config)
        when :triangular
          validate_triangular_distribution(field, config)
        else
          raise ArgumentError, "Unknown distribution type: #{type} for field #{field}"
        end
      end

      def validate_normal_distribution(field, config)
        return if (config[:mean] || config["mean"]) && (config[:stddev] || config["stddev"])

        raise ArgumentError, "Normal distribution for #{field} requires :mean and :stddev"
      end

      def validate_uniform_distribution(field, config)
        return if (config[:min] || config["min"]) && (config[:max] || config["max"])

        raise ArgumentError, "Uniform distribution for #{field} requires :min and :max"
      end

      def validate_lognormal_distribution(field, config)
        return if (config[:mean] || config["mean"]) && (config[:stddev] || config["stddev"])

        raise ArgumentError, "Log-normal distribution for #{field} requires :mean and :stddev"
      end

      def validate_exponential_distribution(field, config)
        return if config[:lambda] || config["lambda"]

        raise ArgumentError, "Exponential distribution for #{field} requires :lambda"
      end

      def validate_discrete_distribution(field, config)
        values = config[:values] || config["values"]
        probs = config[:probabilities] || config["probabilities"]
        raise ArgumentError, "Discrete distribution for #{field} requires :values and :probabilities" unless values && probs

        raise ArgumentError, "Discrete distribution for #{field}: values and probabilities must have same length" unless values.size == probs.size

        sum = probs.sum
        return if (sum - 1.0).abs < 0.001

        raise ArgumentError, "Discrete distribution for #{field}: probabilities must sum to 1.0 (got #{sum})"
      end

      def validate_triangular_distribution(field, config)
        return if (config[:min] || config["min"]) && (config[:mode] || config["mode"]) && (config[:max] || config["max"])

        raise ArgumentError, "Triangular distribution for #{field} requires :min, :mode, and :max"
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

      def run_iterations(distributions:, base_context:, iterations:, agent:, options:)
        if options[:parallel] && iterations > 100
          run_parallel_iterations(distributions, base_context, iterations, agent, options)
        else
          results = []
          attempted = 0
          iterations.times do
            attempted += 1
            context = sample_context(distributions, base_context)
            begin
              decision = agent.decide(context: Context.new(context))
              results << {
                context: context,
                decision: decision.decision,
                confidence: decision.confidence,
                explanations: decision.explanations
              }
            rescue NoEvaluationsError
              # Skip iterations where no evaluators return a decision
              # This can happen when rules don't match the sampled context
              next
            end
          end
          # Store attempted count in results metadata
          results.instance_variable_set(:@attempted_iterations, attempted) if results.respond_to?(:instance_variable_set)
          results
        end
      end

      def run_parallel_iterations(distributions, base_context, iterations, agent, options)
        thread_count = [options[:thread_count], iterations].min
        iterations_per_thread = (iterations.to_f / thread_count).ceil

        threads = create_iteration_threads(
          thread_count, iterations_per_thread, distributions, base_context, agent
        )
        all_results = collect_thread_results(threads)
        limit_results_to_count(all_results, iterations)
      end

      def create_iteration_threads(thread_count, iterations_per_thread, distributions, base_context, agent)
        Array.new(thread_count) do
          Thread.new do
            run_thread_iterations(iterations_per_thread, distributions, base_context, agent)
          end
        end
      end

      def run_thread_iterations(iterations_per_thread, distributions, base_context, agent)
        thread_results = []
        thread_attempted = 0
        iterations_per_thread.times do
          thread_attempted += 1
          result = attempt_iteration(distributions, base_context, agent)
          thread_results << result if result
        end
        store_attempted_count(thread_results, thread_attempted)
        thread_results
      end

      def attempt_iteration(distributions, base_context, agent)
        context = sample_context(distributions, base_context)
        decision = agent.decide(context: Context.new(context))
        {
          context: context,
          decision: decision.decision,
          confidence: decision.confidence,
          explanations: decision.explanations
        }
      rescue StandardError
        nil
      end

      def store_attempted_count(results, attempted)
        return unless results.respond_to?(:instance_variable_set)

        results.instance_variable_set(:@attempted_iterations, attempted)
      end

      def collect_thread_results(threads)
        all_results = threads.map(&:value).flatten.compact
        total_attempted = calculate_total_attempted(threads)
        store_attempted_count(all_results, total_attempted)
        all_results
      end

      def calculate_total_attempted(threads)
        threads.map do |t|
          results = t.value
          results.instance_variable_get(:@attempted_iterations) if results.respond_to?(:instance_variable_get)
        end.compact.sum
      end

      def limit_results_to_count(results, iterations)
        results.first(iterations)
      end

      def sample_context(distributions, base_context)
        context = base_context.dup

        distributions.each do |field, config|
          value = sample_from_distribution(config)
          set_nested_value(context, field, value)
        end

        context
      end

      def sample_from_distribution(config)
        type = (config[:type] || config["type"]).to_sym

        case type
        when :normal
          sample_normal(config)
        when :uniform
          sample_uniform(config)
        when :lognormal
          sample_lognormal(config)
        when :exponential
          sample_exponential(config)
        when :discrete
          sample_discrete(config[:values] || config["values"], config[:probabilities] || config["probabilities"])
        when :triangular
          sample_triangular(config[:min] || config["min"], config[:mode] || config["mode"], config[:max] || config["max"])
        else
          raise ArgumentError, "Unknown distribution type: #{type}"
        end
      end

      def sample_normal(config)
        mean = config[:mean] || config["mean"]
        stddev = config[:stddev] || config["stddev"]
        # Box-Muller transform for normal distribution
        u1 = rand
        u2 = rand
        z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
        mean + (z0 * stddev)
      end

      def sample_uniform(config)
        min = config[:min] || config["min"]
        max = config[:max] || config["max"]
        min + (rand * (max - min))
      end

      def sample_lognormal(config)
        mean = config[:mean] || config["mean"]
        stddev = config[:stddev] || config["stddev"]
        # Sample from normal, then exponentiate
        u1 = rand
        u2 = rand
        z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
        normal_sample = mean + (z0 * stddev)
        Math.exp(normal_sample)
      end

      def sample_exponential(config)
        lambda = config[:lambda] || config["lambda"]
        -Math.log(rand) / lambda
      end

      def sample_discrete(values, probabilities)
        r = rand
        cumulative = 0.0

        values.each_with_index do |value, i|
          cumulative += probabilities[i]
          return value if r <= cumulative
        end

        values.last
      end

      def sample_triangular(min, mode, max)
        u = rand
        f = (mode - min).to_f / (max - min)

        if u < f
          min + Math.sqrt(u * (max - min) * (mode - min))
        else
          max - Math.sqrt((1 - u) * (max - min) * (max - mode))
        end
      end

      def calculate_statistics(results, confidence_level, requested_iterations: nil)
        iterations_count = requested_iterations || results.size
        return empty_statistics(iterations_count, confidence_level) if results.empty?

        decision_stats = calculate_decision_statistics(results)
        confidence_stats = calculate_confidence_statistics(results, confidence_level)
        decision_specific_stats = calculate_decision_specific_statistics(results, decision_stats)

        {
          iterations: iterations_count,
          decision_counts: decision_stats[:counts],
          decision_probabilities: decision_stats[:probabilities],
          decision_stats: decision_specific_stats,
          average_confidence: confidence_stats[:average],
          confidence_stddev: confidence_stats[:stddev],
          confidence_intervals: {
            confidence: confidence_stats[:interval],
            level: confidence_level
          },
          results: results
        }
      end

      def calculate_decision_statistics(results)
        total = results.size
        decision_counts = results.group_by { |r| r[:decision] }.transform_values(&:count)
        decision_probabilities = decision_counts.transform_values { |count| count.to_f / total }

        { counts: decision_counts, probabilities: decision_probabilities }
      end

      def calculate_confidence_statistics(results, confidence_level)
        confidences = results.map { |r| r[:confidence] }.compact
        avg_confidence = confidences.any? ? confidences.sum / confidences.size : 0.0

        if confidences.size > 1
          variance = confidences.map { |c| (c - avg_confidence)**2 }.sum / confidences.size
          stddev_confidence = Math.sqrt(variance)
          confidence_interval = calculate_confidence_interval(confidences, confidence_level)
        else
          stddev_confidence = 0.0
          confidence_interval = { lower: avg_confidence, upper: avg_confidence }
        end

        { average: avg_confidence, stddev: stddev_confidence, interval: confidence_interval }
      end

      def calculate_decision_specific_statistics(results, decision_stats)
        decision_stats[:counts].each_with_object({}) do |(decision, _count), stats|
          decision_results = results.select { |r| r[:decision] == decision }
          decision_confidences = decision_results.map { |r| r[:confidence] }.compact

          next unless decision_confidences.any?

          decision_avg_confidence = decision_confidences.sum / decision_confidences.size
          stats[decision] = {
            count: decision_stats[:counts][decision],
            probability: decision_stats[:probabilities][decision],
            average_confidence: decision_avg_confidence
          }

          next unless decision_confidences.size > 1

          decision_variance = decision_confidences.map { |c| (c - decision_avg_confidence)**2 }.sum / decision_confidences.size
          stats[decision][:confidence_stddev] = Math.sqrt(decision_variance)
        end
      end

      def calculate_confidence_interval(values, level)
        return { lower: values.first, upper: values.first } if values.size <= 1

        sorted = values.sort
        alpha = 1.0 - level
        lower_percentile = (alpha / 2.0) * 100
        upper_percentile = (1.0 - (alpha / 2.0)) * 100

        lower_idx = (lower_percentile / 100.0 * (sorted.size - 1)).round
        upper_idx = (upper_percentile / 100.0 * (sorted.size - 1)).round

        {
          lower: sorted[[lower_idx, 0].max],
          upper: sorted[[upper_idx, sorted.size - 1].min]
        }
      end

      def empty_statistics(attempted_iterations = 0, confidence_level = 0.95)
        {
          iterations: attempted_iterations,
          decision_counts: {},
          decision_probabilities: {},
          decision_stats: {},
          average_confidence: 0.0,
          confidence_stddev: 0.0,
          confidence_intervals: { confidence: { lower: 0.0, upper: 0.0 }, level: confidence_level },
          results: []
        }
      end

      def analyze_parameter_impact(param_results)
        return {} if param_results.empty?

        # Calculate how much decision probabilities change across parameter values
        all_decisions = param_results.flat_map { |r| r[:decision_probabilities].keys }.uniq

        impact = {}
        all_decisions.each do |decision|
          probabilities = param_results.map { |r| r[:decision_probabilities][decision] || 0.0 }
          min_prob = probabilities.min
          max_prob = probabilities.max
          range = max_prob - min_prob

          impact[decision] = {
            min_probability: min_prob,
            max_probability: max_prob,
            range: range,
            sensitivity: if range > 0.1
                           "high"
                         else
                           (range > 0.05 ? "medium" : "low")
                         end
          }
        end

        impact
      end

      def set_nested_value(hash, key, value)
        keys = key.to_s.split(".")
        last_key = keys.pop
        target = keys.reduce(hash) do |h, k|
          h[k.to_sym] ||= {}
        end
        target[last_key.to_sym] = value
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
