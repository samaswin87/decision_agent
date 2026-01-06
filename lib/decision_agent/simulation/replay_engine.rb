require "csv"
require "json"
require_relative "errors"

# Conditionally require ActiveRecord if available
begin
  require "active_record"
rescue LoadError
  # ActiveRecord not available - database queries will raise an error
end

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
      # @param historical_data [String, Array<Hash>, Hash] Path to CSV/JSON file, array of context hashes, or database query config
      #   Database config format: { database: { connection: {...}, query: "SELECT ..." } }
      #   or { database: { connection: {...}, table: "table_name", where: {...} } }
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
      # @param historical_data [String, Array<Hash>, Hash] Historical context data (file path, array, or database config)
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
        when Hash
          if data.key?(:database) || data.key?("database")
            load_database(data[:database] || data["database"])
          else
            raise InvalidHistoricalDataError, "Historical data Hash must contain :database key for database queries"
          end
        else
          raise InvalidHistoricalDataError, "Historical data must be a file path (String), array of contexts, or database query config (Hash)"
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
          context = row.to_h
          # Convert numeric strings to numbers for better evaluator compatibility
          context = context.transform_values do |v|
            # Try to convert to number if it looks like a number
            if v.is_a?(String) && v.match?(/^-?\d+(\.\d+)?$/)
              v.include?('.') ? v.to_f : v.to_i
            else
              v
            end
          end
          contexts << context
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

      def load_database(config)
        unless defined?(ActiveRecord)
          raise InvalidHistoricalDataError, "ActiveRecord is required for database queries. Add 'activerecord' to your Gemfile."
        end

        config = config.is_a?(Hash) ? config : {}
        connection_config = config[:connection] || config["connection"]
        query = config[:query] || config["query"]
        table = config[:table] || config["table"]
        where_clause = config[:where] || config["where"]

        raise InvalidHistoricalDataError, "Database config must include :connection" unless connection_config

        # Check if query or table is provided
        unless query || table
          raise InvalidHistoricalDataError, "Database config must include :query or :table"
        end

        # Establish connection
        connection = establish_database_connection(connection_config)

        # Build and execute query
        contexts = execute_database_query(connection, query: query, table: table, where: where_clause)

        contexts
      rescue ActiveRecord::ActiveRecordError => e
        raise InvalidHistoricalDataError, "Database query failed: #{e.message}"
      rescue StandardError => e
        # Check if it's the missing query/table error
        if e.message.include?("query or :table")
          raise InvalidHistoricalDataError, "Database config must include :query or :table"
        end
        raise InvalidHistoricalDataError, "Failed to load from database: #{e.message}"
      end

      def establish_database_connection(config)
        # If config is a string, assume it's a connection name/key or "default"
        # Otherwise, treat it as connection parameters
        if config.is_a?(String)
          if config == "default" || config.empty?
            # Use default ActiveRecord connection
            ActiveRecord::Base.connection
          else
            # Try to find existing connection by name
            # For now, fall back to default connection
            ActiveRecord::Base.connection
          end
        elsif config.is_a?(Hash)
          # Create a properly named class to avoid "Anonymous class is not allowed" error
          # Generate a unique class name
          class_name = "DecisionAgentReplayConnection#{object_id}#{Thread.current.object_id}#{Time.now.to_f.to_s.gsub(/[^0-9]/, '')}"
          
          # Create the class in the DecisionAgent module namespace
          unless defined?(DecisionAgent::ReplayConnections)
            DecisionAgent.const_set(:ReplayConnections, Module.new)
          end
          
          connection_class = Class.new(ActiveRecord::Base) do
            self.abstract_class = true
          end
          
          # Set the class name properly to avoid anonymous class error
          DecisionAgent::ReplayConnections.const_set(class_name, connection_class)
          connection_class.establish_connection(config)
          connection_class.connection
        else
          raise InvalidHistoricalDataError, "Connection config must be a Hash or String"
        end
      end

      def execute_database_query(connection, query: nil, table: nil, where: nil)
        if query
          # Execute raw SQL query
          results = connection.select_all(query)
          convert_query_results_to_contexts(results)
        elsif table
          # Build SQL query from table and where clause
          sql = build_table_query(connection, table, where)
          results = connection.select_all(sql)
          convert_query_results_to_contexts(results)
        else
          raise InvalidHistoricalDataError, "Database config must include :query or :table"
        end
      end

      def build_table_query(connection, table, where)
        table_name = connection.quote_table_name(table)
        sql = "SELECT * FROM #{table_name}"

        if where && where.is_a?(Hash) && !where.empty?
          where_conditions = where.map do |key, value|
            quoted_key = connection.quote_column_name(key.to_s)
            quoted_value = connection.quote(value)
            "#{quoted_key} = #{quoted_value}"
          end.join(" AND ")
          sql += " WHERE #{where_conditions}"
        end

        sql
      end

      def convert_query_results_to_contexts(results)
        contexts = []

        # Handle ActiveRecord::Result (from select_all)
        if results.respond_to?(:columns) && results.respond_to?(:rows)
          # ActiveRecord::Result format
          columns = results.columns.map(&:to_sym)
          results.rows.each do |row|
            context = {}
            columns.each_with_index do |column, index|
              # Skip common ActiveRecord metadata fields unless they're needed
              next if %i[id created_at updated_at].include?(column) && row[index].nil?

              value = row[index]
              # Convert JSON strings to hashes if detected
              if value.is_a?(String) && (value.start_with?("{") || value.start_with?("["))
                begin
                  value = JSON.parse(value, symbolize_names: true)
                rescue JSON::ParserError
                  # Keep as string if not valid JSON
                end
              end
              context[column] = value
            end
            contexts << context
          end
        elsif results.is_a?(Array)
          # Array of hashes or arrays
          results.each do |row|
            context = if row.is_a?(Hash)
                        row.transform_keys(&:to_sym)
                      else
                        # Convert array to hash if we have column names
                        {}
                      end
            # Remove common ActiveRecord metadata fields if they're nil or not needed
            context = context.reject { |k, v| %i[id created_at updated_at].include?(k) && v.nil? }
            contexts << context unless context.empty?
          end
        elsif results.respond_to?(:each)
          # Enumerable result set
          results.each do |row|
            context = row.is_a?(Hash) ? row.transform_keys(&:to_sym) : row.to_h
            context = context.reject { |k, v| %i[id created_at updated_at].include?(k) && v.nil? }
            contexts << context unless context.empty?
          end
        else
          raise InvalidHistoricalDataError, "Unexpected query result format: #{results.class}"
        end

        contexts
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

        begin
          replay_decision = replay_agent.decide(context: ctx)
        rescue NoEvaluationsError
          # If no evaluators match, return a default result
          return {
            context: ctx.to_h,
            replay_decision: nil,
            replay_confidence: 0.0,
            baseline_decision: nil,
            baseline_confidence: 0.0,
            changed: false,
            confidence_delta: nil,
            error: "No evaluators returned a decision"
          }
        end

        begin
          baseline_decision = baseline_agent&.decide(context: ctx)
        rescue NoEvaluationsError
          baseline_decision = nil
        end

        {
          context: ctx.to_h,
          replay_decision: replay_decision.decision,
          replay_confidence: replay_decision.confidence,
          baseline_decision: baseline_decision&.decision,
          baseline_confidence: baseline_decision&.confidence,
          changed: (baseline_decision&.decision || nil) != replay_decision.decision,
          confidence_delta: baseline_decision ? (replay_decision.confidence - baseline_decision.confidence) : nil
        }
      end

      def build_comparison_report(results, baseline_agent)
        # Filter out results with errors for statistics, but count all for total_decisions
        valid_results = results.reject { |r| r[:error] }
        total = results.size  # Total contexts processed
        changed = valid_results.count { |r| r[:changed] }
        unchanged = valid_results.size - changed

        confidence_deltas = valid_results.map { |r| r[:confidence_delta] }.compact
        avg_confidence_delta = confidence_deltas.any? ? confidence_deltas.sum / confidence_deltas.size : 0

        decision_distribution = valid_results.group_by { |r| r[:replay_decision] }.transform_values(&:count)
        baseline_distribution = valid_results.select { |r| r[:baseline_decision] }
                                      .group_by { |r| r[:baseline_decision] }
                                      .transform_values(&:count)

        {
          total_decisions: total,
          changed_decisions: changed,
          unchanged_decisions: unchanged,
          change_rate: valid_results.size > 0 ? (changed.to_f / valid_results.size) : 0,
          average_confidence_delta: avg_confidence_delta,
          decision_distribution: decision_distribution,
          baseline_distribution: baseline_distribution,
          results: results,
          has_baseline: !baseline_agent.nil?,
          errors: results.count { |r| r[:error] }
        }
      end
    end
  end
end

