require "json"

module DecisionAgent
  module Testing
    # Result of a single test scenario execution
    class TestResult
      attr_reader :scenario_id, :decision, :confidence, :execution_time_ms, :error, :evaluations

      def initialize(scenario_id:, decision: nil, confidence: nil, execution_time_ms: 0, error: nil, evaluations: [])
        @scenario_id = scenario_id.to_s.freeze
        @decision = decision&.to_s&.freeze
        @confidence = confidence&.to_f
        @execution_time_ms = execution_time_ms.to_f
        @error = error
        @evaluations = evaluations.freeze

        freeze
      end

      def success?
        @error.nil?
      end

      def to_h
        {
          scenario_id: @scenario_id,
          decision: @decision,
          confidence: @confidence,
          execution_time_ms: @execution_time_ms,
          error: @error&.message,
          success: success?,
          evaluations: @evaluations.map { |e| e.respond_to?(:to_h) ? e.to_h : e }
        }
      end
    end

    # Executes batch tests against an agent
    class BatchTestRunner
      attr_reader :agent, :results

      def initialize(agent)
        @agent = agent
        @results = []
        @checkpoint_file = nil
      end

      # Run batch tests against scenarios
      # @param scenarios [Array<TestScenario>] Test scenarios to execute
      # @param options [Hash] Execution options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads for parallel execution (default: 4)
      #   - :progress_callback [Proc] Callback for progress updates (called with { completed: N, total: M, percentage: X })
      #   - :feedback [Hash] Optional feedback to pass to agent
      #   - :checkpoint_file [String] Path to checkpoint file for resume capability (optional)
      # @return [Array<TestResult>] Array of test results
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def run(scenarios, options = {})
        @results = []
        @checkpoint_file = options[:checkpoint_file]
        options = {
          parallel: true,
          thread_count: 4,
          progress_callback: nil,
          feedback: {},
          checkpoint_file: nil
        }.merge(options)

        total = scenarios.size
        completed = 0
        mutex = Mutex.new

        # Load checkpoint if exists
        completed_scenario_ids = load_checkpoint if @checkpoint_file && File.exist?(@checkpoint_file)

        # Filter out already completed scenarios
        remaining_scenarios = if completed_scenario_ids&.any?
                                scenarios.reject { |s| completed_scenario_ids.include?(s.id) }
                              else
                                scenarios
                              end

        if options[:parallel] && remaining_scenarios.size > 1
          run_parallel(remaining_scenarios, options, mutex) do |result|
            completed += 1
            save_checkpoint(result.scenario_id) if @checkpoint_file
            options[:progress_callback]&.call(
              completed: completed + (completed_scenario_ids&.size || 0),
              total: total,
              percentage: ((completed + (completed_scenario_ids&.size || 0)).to_f / total * 100).round(2)
            )
          end
        else
          remaining_scenarios.each_with_index do |scenario, index|
            result = execute_scenario(scenario, options[:feedback])
            @results << result
            save_checkpoint(result.scenario_id) if @checkpoint_file
            completed = index + 1
            options[:progress_callback]&.call(
              completed: completed + (completed_scenario_ids&.size || 0),
              total: total,
              percentage: ((completed + (completed_scenario_ids&.size || 0)).to_f / total * 100).round(2)
            )
          end
        end

        # Clean up checkpoint file on successful completion
        delete_checkpoint if @checkpoint_file && File.exist?(@checkpoint_file)

        @results
      end

      # Resume batch test execution from a checkpoint
      # @param scenarios [Array<TestScenario>] All test scenarios (including already completed ones)
      # @param checkpoint_file [String] Path to checkpoint file
      # @param options [Hash] Same as run method
      # @return [Array<TestResult>] Array of test results (only newly executed ones)
      def resume(scenarios, checkpoint_file, options = {})
        options[:checkpoint_file] = checkpoint_file
        run(scenarios, options)
      end

      # Get execution statistics
      # @return [Hash] Statistics about the batch test run
      def statistics
        return {} if @results.empty?

        successful = @results.count(&:success?)
        failed = @results.size - successful
        execution_times = @results.map(&:execution_time_ms).compact

        {
          total: @results.size,
          successful: successful,
          failed: failed,
          success_rate: successful.to_f / @results.size,
          avg_execution_time_ms: execution_times.any? ? execution_times.sum / execution_times.size : 0,
          min_execution_time_ms: execution_times.min || 0,
          max_execution_time_ms: execution_times.max || 0,
          total_execution_time_ms: execution_times.sum
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      private

      def run_parallel(scenarios, options, mutex)
        thread_count = [options[:thread_count], scenarios.size].min
        queue = Queue.new
        scenarios.each { |s| queue << s }

        threads = Array.new(thread_count) do
          Thread.new do
            loop do
              scenario = begin
                queue.pop(true)
              rescue StandardError
                nil
              end
              break unless scenario

              result = execute_scenario(scenario, options[:feedback])
              mutex.synchronize do
                @results << result
                yield result
              end
            end
          end
        end

        threads.each(&:join)
      end

      def execute_scenario(scenario, feedback)
        start_time = Time.now

        begin
          decision = @agent.decide(context: scenario.context, feedback: feedback)

          execution_time_ms = ((Time.now - start_time) * 1000).round(2)

          TestResult.new(
            scenario_id: scenario.id,
            decision: decision.decision,
            confidence: decision.confidence,
            execution_time_ms: execution_time_ms,
            evaluations: decision.evaluations
          )
        rescue StandardError => e
          execution_time_ms = ((Time.now - start_time) * 1000).round(2)

          TestResult.new(
            scenario_id: scenario.id,
            execution_time_ms: execution_time_ms,
            error: e
          )
        end
      end

      def save_checkpoint(scenario_id)
        return unless @checkpoint_file

        checkpoint_data = load_checkpoint_data
        checkpoint_data[:completed_scenario_ids] << scenario_id.to_s unless checkpoint_data[:completed_scenario_ids].include?(scenario_id.to_s)
        checkpoint_data[:last_updated] = Time.now.to_i

        File.write(@checkpoint_file, JSON.pretty_generate(checkpoint_data))
      rescue StandardError => e
        # Silently fail checkpoint saving to not interrupt test execution
        warn "Failed to save checkpoint: #{e.message}" if $VERBOSE
      end

      def load_checkpoint
        return [] unless @checkpoint_file && File.exist?(@checkpoint_file)

        checkpoint_data = load_checkpoint_data
        checkpoint_data[:completed_scenario_ids] || []
      rescue StandardError => e
        warn "Failed to load checkpoint: #{e.message}" if $VERBOSE
        []
      end

      def load_checkpoint_data
        return { completed_scenario_ids: [], last_updated: nil } unless @checkpoint_file && File.exist?(@checkpoint_file)

        content = File.read(@checkpoint_file)
        data = JSON.parse(content, symbolize_names: true)
        data[:completed_scenario_ids] ||= []
        data
      rescue JSON::ParserError
        { completed_scenario_ids: [], last_updated: nil }
      rescue StandardError
        { completed_scenario_ids: [], last_updated: nil }
      end

      def delete_checkpoint
        return unless @checkpoint_file && File.exist?(@checkpoint_file)

        File.delete(@checkpoint_file)
      rescue StandardError => e
        warn "Failed to delete checkpoint: #{e.message}" if $VERBOSE
      end
    end
  end
end
