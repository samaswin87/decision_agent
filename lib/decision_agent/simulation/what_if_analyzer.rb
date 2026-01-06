require_relative "errors"

module DecisionAgent
  module Simulation
    # Analyzer for what-if scenario simulation
    class WhatIfAnalyzer
      attr_reader :agent, :version_manager

      def initialize(agent:, version_manager: nil)
        @agent = agent
        @version_manager = version_manager || Versioning::VersionManager.new
      end

      # Analyze multiple scenarios
      # @param scenarios [Array<Hash>] Array of context hashes to simulate
      # @param rule_version [String, Integer, Hash, nil] Optional rule version to use
      # @param options [Hash] Analysis options
      #   - :parallel [Boolean] Use parallel execution (default: true)
      #   - :thread_count [Integer] Number of threads (default: 4)
      #   - :sensitivity_analysis [Boolean] Perform sensitivity analysis (default: false)
      # @return [Hash] Analysis results with decision outcomes
      def analyze(scenarios:, rule_version: nil, options: {})
        options = {
          parallel: true,
          thread_count: 4,
          sensitivity_analysis: false
        }.merge(options)

        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        results = execute_scenarios(scenarios, analysis_agent, options)

        report = {
          scenarios: results,
          total_scenarios: scenarios.size,
          decision_distribution: results.group_by { |r| r[:decision] }.transform_values(&:count),
          average_confidence: calculate_average_confidence(results)
        }

        report[:sensitivity] = perform_sensitivity_analysis(scenarios, analysis_agent) if options[:sensitivity_analysis]

        report
      end

      # Perform sensitivity analysis to identify which inputs affect decisions most
      # @param base_scenario [Hash] Base context to vary
      # @param variations [Hash] Hash of field => [values] to test
      # @param rule_version [String, Integer, Hash, nil] Optional rule version
      # @return [Hash] Sensitivity analysis results
      def sensitivity_analysis(base_scenario:, variations:, rule_version: nil)
        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        base_decision = analysis_agent.decide(context: Context.new(base_scenario))
        base_decision_value = base_decision.decision

        sensitivity_results = analyze_field_variations(
          base_scenario, variations, base_decision_value, analysis_agent
        )

        build_sensitivity_result(
          base_scenario, base_decision_value, base_decision.confidence, sensitivity_results
        )
      end

      def analyze_field_variations(base_scenario, variations, base_decision_value, analysis_agent)
        variations.each_with_object({}) do |(field, values), results|
          field_results = test_field_values(base_scenario, field, values, base_decision_value, analysis_agent)
          results[field] = build_field_sensitivity(field_results, values.size, base_decision_value)
        end
      end

      def test_field_values(base_scenario, field, values, base_decision_value, analysis_agent)
        values.map do |value|
          modified_scenario = base_scenario.dup
          set_nested_value(modified_scenario, field, value)
          decision = analysis_agent.decide(context: Context.new(modified_scenario))
          build_field_result(value, decision, base_decision_value)
        end
      end

      def build_field_result(value, decision, base_decision_value)
        {
          value: value,
          decision: decision.decision,
          confidence: decision.confidence,
          changed: decision.decision != base_decision_value
        }
      end

      def build_field_sensitivity(field_results, values_size, base_decision_value)
        changed_count = field_results.count { |r| r[:changed] }
        {
          impact: changed_count.to_f / values_size,
          results: field_results,
          base_decision: base_decision_value
        }
      end

      def build_sensitivity_result(base_scenario, base_decision_value, base_confidence, sensitivity_results)
        {
          base_scenario: base_scenario,
          base_decision: base_decision_value,
          base_confidence: base_confidence,
          field_sensitivity: sensitivity_results,
          most_sensitive_fields: sensitivity_results.sort_by { |_k, v| -v[:impact] }.to_h.keys
        }
      end

      # Visualize decision boundaries for 1D or 2D parameter spaces
      # @param base_scenario [Hash] Base context with fixed parameter values
      # @param parameters [Hash] Hash of parameter_name => {min, max, steps} for 1D or 2 parameters for 2D
      # @param rule_version [String, Integer, Hash, nil] Optional rule version to use
      # @param options [Hash] Visualization options
      #   - :output_format [String] 'data', 'html', 'json' (default: 'data')
      #   - :resolution [Integer] Number of steps for grid generation (default: 50 for 1D, 20 for 2D)
      # @return [Hash] Decision boundary data or visualization output
      def visualize_decision_boundaries(base_scenario:, parameters:, rule_version: nil, options: {})
        options = {
          output_format: "data",
          resolution: nil
        }.merge(options)

        analysis_agent = build_agent_from_version(rule_version) if rule_version
        analysis_agent ||= @agent

        # Validate parameters
        param_keys = parameters.keys
        raise ArgumentError, "Must specify 1 or 2 parameters for visualization" if param_keys.empty? || param_keys.size > 2

        # Set default resolution
        resolution = options[:resolution] || (param_keys.size == 1 ? 100 : 30)

        if param_keys.size == 1
          visualize_1d_boundary(base_scenario, param_keys.first, parameters[param_keys.first], analysis_agent, options)
        else
          config = {
            base_scenario: base_scenario,
            param1_name: param_keys[0],
            param2_name: param_keys[1],
            param1_config: parameters[param_keys[0]],
            param2_config: parameters[param_keys[1]],
            analysis_agent: analysis_agent,
            resolution: resolution,
            output_options: options
          }
          visualize_2d_boundary(config)
        end
      end

      private

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

      def execute_scenarios(scenarios, analysis_agent, options)
        results = []
        mutex = Mutex.new

        if options[:parallel] && scenarios.size > 1
          execute_parallel(scenarios, analysis_agent, options, mutex) do |result|
            mutex.synchronize { results << result }
          end
        else
          scenarios.each do |scenario|
            ctx = scenario.is_a?(Context) ? scenario : Context.new(scenario)
            decision = analysis_agent.decide(context: ctx)
            results << {
              scenario: ctx.to_h,
              decision: decision.decision,
              confidence: decision.confidence,
              explanations: decision.explanations
            }
          end
        end

        results
      end

      def execute_parallel(scenarios, analysis_agent, options, _mutex)
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

              ctx = scenario.is_a?(Context) ? scenario : Context.new(scenario)
              decision = analysis_agent.decide(context: ctx)
              result = {
                scenario: ctx.to_h,
                decision: decision.decision,
                confidence: decision.confidence,
                explanations: decision.explanations
              }
              yield result
            end
          end
        end

        threads.each(&:join)
      end

      def calculate_average_confidence(results)
        confidences = results.map { |r| r[:confidence] }.compact
        confidences.any? ? confidences.sum / confidences.size : 0
      end

      def perform_sensitivity_analysis(scenarios, analysis_agent)
        # Identify numeric fields that vary across scenarios
        numeric_fields = identify_numeric_fields(scenarios)
        return {} if numeric_fields.empty?

        sensitivity = {}
        numeric_fields.each do |field|
          values = scenarios.map { |s| get_nested_value(s, field) }.compact.uniq
          next if values.size < 2

          # Test impact of varying this field
          base_scenario = scenarios.first.dup
          field_sensitivity = test_field_impact(base_scenario, field, values, analysis_agent)
          sensitivity[field] = field_sensitivity if field_sensitivity
        end

        sensitivity
      end

      def identify_numeric_fields(scenarios)
        return [] if scenarios.empty?

        all_keys = scenarios.flat_map { |s| extract_keys(s) }.uniq
        numeric_keys = []

        all_keys.each do |key|
          values = scenarios.map { |s| get_nested_value(s, key) }.compact
          numeric_keys << key if values.all? { |v| v.is_a?(Numeric) }
        end

        numeric_keys
      end

      def extract_keys(hash, prefix = nil)
        keys = []
        hash.each do |k, v|
          full_key = prefix ? "#{prefix}.#{k}" : k.to_s
          if v.is_a?(Hash)
            keys.concat(extract_keys(v, full_key))
          else
            keys << full_key
          end
        end
        keys
      end

      def test_field_impact(base_scenario, field, values, analysis_agent)
        base_decision = analysis_agent.decide(context: Context.new(base_scenario))
        base_decision_value = base_decision.decision

        changed_count = 0
        values.each do |value|
          modified = base_scenario.dup
          set_nested_value(modified, field, value)
          decision = analysis_agent.decide(context: Context.new(modified))
          changed_count += 1 if decision.decision != base_decision_value
        end

        {
          impact: changed_count.to_f / values.size,
          values_tested: values.size,
          decisions_changed: changed_count
        }
      end

      def get_nested_value(hash, key)
        keys = key.to_s.split(".")
        keys.reduce(hash) do |h, k|
          return nil unless h.is_a?(Hash)

          h[k.to_sym] || h[k.to_s]
        end
      end

      def set_nested_value(hash, key, value)
        keys = key.to_s.split(".")
        last_key = keys.pop
        target = keys.reduce(hash) do |h, k|
          h[k.to_sym] ||= {}
        end
        target[last_key.to_sym] = value
      end

      # Generate 1D decision boundary visualization
      def visualize_1d_boundary(base_scenario, param_name, param_config, analysis_agent, options)
        min, max, steps = extract_1d_params(param_config)
        points = generate_1d_points(base_scenario, param_name, min, max, steps, analysis_agent)
        boundaries = identify_1d_boundaries(points)
        result = build_1d_result(param_name, min, max, points, boundaries)

        format_visualization_output(result, options)
      end

      def extract_1d_params(param_config)
        min = param_config[:min] || param_config["min"]
        max = param_config[:max] || param_config["max"]
        steps = param_config[:steps] || param_config["steps"] || 100

        raise ArgumentError, "Parameter config must include :min and :max" unless min && max

        [min, max, steps]
      end

      def generate_1d_points(base_scenario, param_name, min, max, steps, analysis_agent)
        step_size = (max - min).to_f / steps
        (0..steps).each_with_object([]) do |i, points|
          value = min + (step_size * i)
          point = evaluate_1d_point(base_scenario, param_name, value, analysis_agent)
          points << point.merge(parameter: param_name, value: value)
        end
      end

      def evaluate_1d_point(base_scenario, param_name, value, analysis_agent)
        modified_scenario = base_scenario.dup
        set_nested_value(modified_scenario, param_name, value)

        decision = analysis_agent.decide(context: Context.new(modified_scenario))
        { decision: decision.decision, confidence: decision.confidence }
      rescue DecisionAgent::NoEvaluationsError
        { decision: nil, confidence: 0.0 }
      end

      def identify_1d_boundaries(points)
        points.each_cons(2).with_object([]) do |(p1, p2), boundaries|
          next unless p1[:decision] != p2[:decision]

          boundary_value = p1[:value] + ((p2[:value] - p1[:value]) / 2.0)
          boundaries << {
            value: boundary_value,
            decision_from: p1[:decision],
            decision_to: p2[:decision],
            confidence_from: p1[:confidence],
            confidence_to: p2[:confidence]
          }
        end
      end

      def build_1d_result(param_name, min, max, points, boundaries)
        {
          type: "1d_boundary",
          parameter: param_name,
          range: { min: min, max: max },
          points: points,
          boundaries: boundaries,
          decision_distribution: points.any? ? points.group_by { |p| p[:decision] }.transform_values(&:count) : {}
        }
      end

      # Generate 2D decision boundary visualization
      def visualize_2d_boundary(config)
        params = extract_2d_params(config[:param1_config], config[:param2_config])
        grid_config = GridConfig.build(
          base_scenario: config[:base_scenario],
          param1_name: config[:param1_name],
          param2_name: config[:param2_name],
          params: params,
          resolution: config[:resolution],
          analysis_agent: config[:analysis_agent]
        )
        grid = generate_2d_grid(grid_config)
        boundaries = identify_2d_boundaries(grid, config[:resolution])
        result = build_2d_result(grid_config, grid, boundaries)

        format_visualization_output(result, config[:output_options])
      end

      # Configuration object for 2D grid generation
      class GridConfig
        attr_reader :base_scenario, :param1_name, :param2_name, :min1, :max1, :min2, :max2, :resolution, :analysis_agent

        def self.build(base_scenario:, param1_name:, param2_name:, params:, resolution:, analysis_agent:)
          config_hash = {
            base_scenario: base_scenario,
            param1_name: param1_name,
            param2_name: param2_name,
            min1: params[:min1],
            max1: params[:max1],
            min2: params[:min2],
            max2: params[:max2],
            resolution: resolution,
            analysis_agent: analysis_agent
          }
          new(config_hash)
        end

        private

        def initialize(config)
          @base_scenario = config[:base_scenario]
          @param1_name = config[:param1_name]
          @param2_name = config[:param2_name]
          @min1 = config[:min1]
          @max1 = config[:max1]
          @min2 = config[:min2]
          @max2 = config[:max2]
          @resolution = config[:resolution]
          @analysis_agent = config[:analysis_agent]
        end
      end

      def extract_2d_params(param1_config, param2_config)
        min1 = param1_config[:min] || param1_config["min"]
        max1 = param1_config[:max] || param1_config["max"]
        min2 = param2_config[:min] || param2_config["min"]
        max2 = param2_config[:max] || param2_config["max"]

        raise ArgumentError, "Parameter configs must include :min and :max" unless min1 && max1 && min2 && max2

        { min1: min1, max1: max1, min2: min2, max2: max2 }
      end

      def generate_2d_grid(grid_config)
        step1 = (grid_config.max1 - grid_config.min1).to_f / grid_config.resolution
        step2 = (grid_config.max2 - grid_config.min2).to_f / grid_config.resolution

        (0..grid_config.resolution).each_with_object([]) do |i, grid|
          value1 = grid_config.min1 + (step1 * i)
          row = generate_2d_row(grid_config, value1, min2: grid_config.min2, step2: step2)
          grid << row
        end
      end

      def generate_2d_row(grid_config, value1, min2:, step2:)
        (0..grid_config.resolution).each_with_object([]) do |j, row|
          value2 = min2 + (step2 * j)
          point = evaluate_2d_point(grid_config, value1, value2)
          row << point.merge(param1: value1, param2: value2)
        end
      end

      def evaluate_2d_point(grid_config, value1, value2)
        modified_scenario = grid_config.base_scenario.dup
        set_nested_value(modified_scenario, grid_config.param1_name, value1)
        set_nested_value(modified_scenario, grid_config.param2_name, value2)

        decision = grid_config.analysis_agent.decide(context: Context.new(modified_scenario))
        { decision: decision.decision, confidence: decision.confidence }
      rescue DecisionAgent::NoEvaluationsError
        { decision: nil, confidence: 0.0 }
      end

      def build_2d_result(grid_config, grid, boundaries)
        decision_counts = grid.flatten.group_by { |p| p[:decision] }.transform_values(&:count)

        {
          type: "2d_boundary",
          parameter1: grid_config.param1_name,
          parameter2: grid_config.param2_name,
          range1: { min: grid_config.min1, max: grid_config.max1 },
          range2: { min: grid_config.min2, max: grid_config.max2 },
          resolution: grid_config.resolution,
          grid: grid,
          boundaries: boundaries,
          decision_distribution: decision_counts
        }
      end

      # Identify boundary lines in 2D grid where decisions change
      def identify_2d_boundaries(grid, resolution)
        find_vertical_boundaries(grid, resolution) + find_horizontal_boundaries(grid, resolution)
      end

      def find_vertical_boundaries(grid, resolution)
        (0..(resolution - 1)).each_with_object([]) do |i, boundaries|
          (0..resolution).each do |j|
            next unless j < resolution && grid[i][j][:decision] != grid[i][j + 1][:decision]

            boundaries << {
              type: "vertical",
              row: i,
              col: j,
              decision_left: grid[i][j][:decision],
              decision_right: grid[i][j + 1][:decision],
              param1: grid[i][j][:param1],
              param2_left: grid[i][j][:param2],
              param2_right: grid[i][j + 1][:param2]
            }
          end
        end
      end

      def find_horizontal_boundaries(grid, resolution)
        (0..resolution).each_with_object([]) do |i, boundaries|
          (0..(resolution - 1)).each do |j|
            next unless i < resolution && grid[i][j][:decision] != grid[i + 1][j][:decision]

            boundaries << {
              type: "horizontal",
              row: i,
              col: j,
              decision_top: grid[i][j][:decision],
              decision_bottom: grid[i + 1][j][:decision],
              param1_top: grid[i][j][:param1],
              param1_bottom: grid[i + 1][j][:param1],
              param2: grid[i][j][:param2]
            }
          end
        end
      end

      # Format visualization output based on requested format
      def format_visualization_output(data, options)
        case options[:output_format]
        when "html"
          generate_html_visualization(data)
        when "json"
          require "json"
          data.to_json
        when "data"
          data
        else
          data
        end
      end

      # Generate HTML visualization with SVG/Canvas plotting
      def generate_html_visualization(data)
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Decision Boundary Visualization</title>
            <style>
              body {
                font-family: Arial, sans-serif;
                margin: 20px;
                background: #f5f5f5;
              }
              .container {
                max-width: 1200px;
                margin: 0 auto;
                background: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              }
              h1 { color: #333; }
              .info {
                background: #f0f0f0;
                padding: 15px;
                border-radius: 4px;
                margin: 20px 0;
              }
              .chart-container {
                margin: 20px 0;
                text-align: center;
              }
              svg {
                border: 1px solid #ddd;
                background: white;
              }
              .legend {
                display: flex;
                justify-content: center;
                gap: 20px;
                margin: 20px 0;
                flex-wrap: wrap;
              }
              .legend-item {
                display: flex;
                align-items: center;
                gap: 8px;
              }
              .legend-color {
                width: 20px;
                height: 20px;
                border: 1px solid #333;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h1>Decision Boundary Visualization</h1>
              <div class="info">
                #{generate_info_html(data)}
              </div>
              <div class="chart-container">
                #{generate_chart_html(data)}
              </div>
              <div class="legend">
                #{generate_legend_html(data)}
              </div>
            </div>
          </body>
          </html>
        HTML
      end

      def generate_info_html(data)
        if data[:type] == "1d_boundary"
          generate_1d_info(data)
        elsif data[:type] == "2d_boundary"
          generate_2d_info(data)
        else
          ""
        end
      end

      def generate_1d_info(data)
        [
          "<strong>Type:</strong> 1D Boundary Visualization",
          "<strong>Parameter:</strong> #{data[:parameter]}",
          "<strong>Range:</strong> #{data[:range][:min]} to #{data[:range][:max]}",
          "<strong>Boundaries Found:</strong> #{data[:boundaries].size}",
          "<strong>Decision Distribution:</strong> #{format_decision_distribution(data[:decision_distribution])}"
        ].join("<br>")
      end

      def generate_2d_info(data)
        [
          "<strong>Type:</strong> 2D Boundary Visualization",
          "<strong>Parameters:</strong> #{data[:parameter1]} vs #{data[:parameter2]}",
          "<strong>Range 1:</strong> #{data[:range1][:min]} to #{data[:range1][:max]}",
          "<strong>Range 2:</strong> #{data[:range2][:min]} to #{data[:range2][:max]}",
          "<strong>Resolution:</strong> #{data[:resolution]}x#{data[:resolution]}",
          "<strong>Boundaries Found:</strong> #{data[:boundaries].size}",
          "<strong>Decision Distribution:</strong> #{format_decision_distribution(data[:decision_distribution])}"
        ].join("<br>")
      end

      def format_decision_distribution(distribution)
        distribution.map { |k, v| "#{k}: #{v}" }.join(", ")
      end

      def generate_chart_html(data)
        if data[:type] == "1d_boundary"
          generate_1d_chart_svg(data)
        elsif data[:type] == "2d_boundary"
          generate_2d_chart_svg(data)
        else
          "<p>Unsupported visualization type</p>"
        end
      end

      def generate_1d_chart_svg(data)
        chart_config = setup_1d_chart(data)
        svg = "<svg width='#{chart_config[:width]}' height='#{chart_config[:height]}'>"

        svg << draw_1d_regions(data, chart_config)
        svg << draw_1d_boundaries(data, chart_config)
        svg << draw_1d_axes(data, chart_config)

        svg << "</svg>"
      end

      def setup_1d_chart(data)
        width = 800
        height = 400
        margin = { top: 40, right: 40, bottom: 60, left: 60 }
        chart_width = width - margin[:left] - margin[:right]
        chart_height = height - margin[:top] - margin[:bottom]

        decisions = data[:points].map { |p| p[:decision] }.uniq
        colors = ["#58a6ff", "#3fb950", "#d29922", "#da3633", "#bc8cff", "#ff79c6", "#bd93f9"]
        decision_colors = decisions.each_with_index.to_h { |d, i| [d, colors[i % colors.size]] }

        min_val = data[:range][:min]
        max_val = data[:range][:max]
        x_scale = chart_width.to_f / (max_val - min_val)

        {
          width: width,
          height: height,
          margin: margin,
          chart_width: chart_width,
          chart_height: chart_height,
          decision_colors: decision_colors,
          min_val: min_val,
          max_val: max_val,
          x_scale: x_scale
        }
      end

      def draw_1d_regions(data, config)
        svg = ""
        current_decision = nil
        region_start = nil

        data[:points].each do |point|
          next unless point[:decision] != current_decision

          if current_decision && region_start
            region_end = config[:margin][:left] + ((point[:value] - config[:min_val]) * config[:x_scale])
            color = config[:decision_colors][current_decision]
            svg << build_region_rect(region_start, region_end, config, color)
          end

          current_decision = point[:decision]
          region_start = config[:margin][:left] + ((point[:value] - config[:min_val]) * config[:x_scale])
        end

        if current_decision && region_start
          region_end = config[:margin][:left] + config[:chart_width]
          color = config[:decision_colors][current_decision]
          svg << build_region_rect(region_start, region_end, config, color)
        end

        svg
      end

      def build_region_rect(region_start, region_end, config, color)
        "<rect x='#{region_start}' y='#{config[:margin][:top]}' " \
          "width='#{region_end - region_start}' height='#{config[:chart_height]}' " \
          "fill='#{color}' opacity='0.3'/>"
      end

      def draw_1d_boundaries(data, config)
        data[:boundaries].each_with_object("") do |boundary, svg|
          x = config[:margin][:left] + ((boundary[:value] - config[:min_val]) * config[:x_scale])
          svg << "<line x1='#{x}' y1='#{config[:margin][:top]}' x2='#{x}' " \
                 "y2='#{config[:margin][:top] + config[:chart_height]}' stroke='#000' " \
                 "stroke-width='2' stroke-dasharray='5,5'/>"
        end
      end

      def draw_1d_axes(data, config)
        svg = draw_1d_axis_lines(config)
        svg << draw_1d_axis_label(data, config)
        svg << draw_1d_tick_marks(config)
      end

      def draw_1d_axis_lines(config)
        margin = config[:margin]
        chart_width = config[:chart_width]
        chart_height = config[:chart_height]

        "<line x1='#{margin[:left]}' y1='#{margin[:top] + chart_height}' " \
          "x2='#{margin[:left] + chart_width}' y2='#{margin[:top] + chart_height}' " \
          "stroke='#333' stroke-width='2'/>" \
          "<line x1='#{margin[:left]}' y1='#{margin[:top]}' " \
          "x2='#{margin[:left]}' y2='#{margin[:top] + chart_height}' " \
          "stroke='#333' stroke-width='2'/>"
      end

      def draw_1d_axis_label(data, config)
        margin = config[:margin]
        chart_width = config[:chart_width]

        "<text x='#{margin[:left] + (chart_width / 2)}' y='#{config[:height] - 10}' " \
          "text-anchor='middle' font-size='14' fill='#333'>#{data[:parameter]}</text>"
      end

      def draw_1d_tick_marks(config)
        margin = config[:margin]
        chart_height = config[:chart_height]

        (0..4).each_with_object("") do |i, svg|
          value = config[:min_val] + ((config[:max_val] - config[:min_val]) * i / 4.0)
          x = margin[:left] + ((value - config[:min_val]) * config[:x_scale])
          svg << "<line x1='#{x}' y1='#{margin[:top] + chart_height}' " \
                 "x2='#{x}' y2='#{margin[:top] + chart_height + 5}' " \
                 "stroke='#333' stroke-width='1'/>"
          svg << "<text x='#{x}' y='#{config[:height] - 20}' text-anchor='middle' font-size='12' fill='#666'>#{value.round(2)}</text>"
        end
      end

      def generate_2d_chart_svg(data)
        chart_config = setup_2d_chart(data)
        svg = "<svg width='#{chart_config[:width]}' height='#{chart_config[:height]}'>"

        svg << draw_2d_grid(data, chart_config)
        svg << draw_2d_boundaries(data, chart_config)
        svg << draw_2d_axes(data, chart_config)

        svg << "</svg>"
      end

      def setup_2d_chart(data)
        dimensions = calculate_chart_dimensions
        decision_colors = build_decision_colors(data)
        scales = calculate_2d_scales(data, dimensions)

        dimensions.merge(decision_colors).merge(scales)
      end

      def calculate_chart_dimensions
        width = 600
        height = 600
        margin = { top: 40, right: 40, bottom: 60, left: 60 }
        chart_width = width - margin[:left] - margin[:right]
        chart_height = height - margin[:top] - margin[:bottom]

        {
          width: width,
          height: height,
          margin: margin,
          chart_width: chart_width,
          chart_height: chart_height
        }
      end

      def build_decision_colors(data)
        decisions = data[:grid].flatten.map { |p| p[:decision] }.uniq
        colors = ["#58a6ff", "#3fb950", "#d29922", "#da3633", "#bc8cff", "#ff79c6", "#bd93f9"]
        { decision_colors: decisions.each_with_index.to_h { |d, i| [d, colors[i % colors.size]] } }
      end

      def calculate_2d_scales(data, dimensions)
        min1 = data[:range1][:min]
        max1 = data[:range1][:max]
        min2 = data[:range2][:min]
        max2 = data[:range2][:max]

        {
          min1: min1,
          max1: max1,
          min2: min2,
          max2: max2,
          x_scale: dimensions[:chart_width].to_f / (max1 - min1),
          y_scale: dimensions[:chart_height].to_f / (max2 - min2),
          cell_width: dimensions[:chart_width].to_f / data[:resolution],
          cell_height: dimensions[:chart_height].to_f / data[:resolution]
        }
      end

      def draw_2d_grid(data, config)
        data[:grid].each_with_index.with_object("") do |(row, i), svg|
          row.each_with_index do |point, j|
            x = config[:margin][:left] + (j * config[:cell_width])
            y = config[:margin][:top] + (i * config[:cell_height])
            color = config[:decision_colors][point[:decision]]
            svg << "<rect x='#{x}' y='#{y}' width='#{config[:cell_width].ceil}' " \
                   "height='#{config[:cell_height].ceil}' fill='#{color}' opacity='0.6' " \
                   "stroke='#ddd' stroke-width='0.5'/>"
          end
        end
      end

      def draw_2d_boundaries(data, config)
        sampled_boundaries = data[:boundaries].sample([data[:boundaries].size, 500].min)
        sampled_boundaries.each_with_object("") do |boundary, svg|
          svg << draw_boundary_line(boundary, config)
        end
      end

      def draw_boundary_line(boundary, config)
        case boundary[:type]
        when "vertical"
          draw_vertical_boundary(boundary, config)
        when "horizontal"
          draw_horizontal_boundary(boundary, config)
        else
          ""
        end
      end

      def draw_vertical_boundary(boundary, config)
        x = config[:margin][:left] + (boundary[:col] * config[:cell_width]) + config[:cell_width]
        y1 = config[:margin][:top] + (boundary[:row] * config[:cell_height])
        y2 = y1 + config[:cell_height]
        "<line x1='#{x}' y1='#{y1}' x2='#{x}' y2='#{y2}' stroke='#000' stroke-width='2'/>"
      end

      def draw_horizontal_boundary(boundary, config)
        x1 = config[:margin][:left] + (boundary[:col] * config[:cell_width])
        x2 = x1 + config[:cell_width]
        y = config[:margin][:top] + (boundary[:row] * config[:cell_height]) + config[:cell_height]
        "<line x1='#{x1}' y1='#{y}' x2='#{x2}' y2='#{y}' stroke='#000' stroke-width='2'/>"
      end

      def draw_2d_axes(data, config)
        svg = draw_2d_axis_lines(config)
        svg << draw_2d_axis_labels(data, config)
        svg << draw_2d_tick_marks(config)
      end

      def draw_2d_axis_lines(config)
        margin = config[:margin]
        chart_width = config[:chart_width]
        chart_height = config[:chart_height]

        "<line x1='#{margin[:left]}' y1='#{margin[:top] + chart_height}' " \
          "x2='#{margin[:left] + chart_width}' y2='#{margin[:top] + chart_height}' " \
          "stroke='#333' stroke-width='2'/>" \
          "<line x1='#{margin[:left]}' y1='#{margin[:top]}' " \
          "x2='#{margin[:left]}' y2='#{margin[:top] + chart_height}' " \
          "stroke='#333' stroke-width='2'/>"
      end

      def draw_2d_axis_labels(data, config)
        margin = config[:margin]
        chart_width = config[:chart_width]
        chart_height = config[:chart_height]

        "<text x='#{margin[:left] + (chart_width / 2)}' y='#{config[:height] - 10}' " \
          "text-anchor='middle' font-size='14' fill='#333'>#{data[:parameter1]}</text>" \
          "<text x='15' y='#{margin[:top] + (chart_height / 2)}' " \
          "text-anchor='middle' font-size='14' fill='#333' " \
          "transform='rotate(-90, 15, #{margin[:top] + (chart_height / 2)})'>" \
          "#{data[:parameter2]}</text>"
      end

      def draw_2d_tick_marks(config)
        margin = config[:margin]
        chart_height = config[:chart_height]

        (0..4).each_with_object("") do |index, svg|
          svg << draw_2d_x_tick(index, config, margin, chart_height)
          svg << draw_2d_y_tick(index, config, margin)
        end
      end

      def draw_2d_x_tick(index, config, margin, chart_height)
        value1 = config[:min1] + ((config[:max1] - config[:min1]) * index / 4.0)
        x = margin[:left] + ((value1 - config[:min1]) * config[:x_scale])
        "<line x1='#{x}' y1='#{margin[:top] + chart_height}' " \
          "x2='#{x}' y2='#{margin[:top] + chart_height + 5}' " \
          "stroke='#333' stroke-width='1'/>" \
          "<text x='#{x}' y='#{config[:height] - 20}' text-anchor='middle' font-size='10' fill='#666'>#{value1.round(2)}</text>"
      end

      def draw_2d_y_tick(index, config, margin)
        value2 = config[:max2] - ((config[:max2] - config[:min2]) * index / 4.0)
        y = margin[:top] + ((value2 - config[:min2]) * config[:y_scale])
        "<line x1='#{margin[:left]}' y1='#{y}' x2='#{margin[:left] - 5}' y2='#{y}' stroke='#333' stroke-width='1'/>" \
          "<text x='#{margin[:left] - 10}' y='#{y + 4}' text-anchor='end' font-size='10' fill='#666'>#{value2.round(2)}</text>"
      end

      def generate_legend_html(data)
        decisions = if data[:type] == "1d_boundary"
                      data[:points].map { |p| p[:decision] }.uniq
                    else
                      data[:grid].flatten.map { |p| p[:decision] }.uniq
                    end

        colors = ["#58a6ff", "#3fb950", "#d29922", "#da3633", "#bc8cff", "#ff79c6", "#bd93f9"]

        decisions.map.with_index do |decision, i|
          color = colors[i % colors.size]
          "<div class='legend-item'><div class='legend-color' style='background: #{color};'></div><span>#{decision}</span></div>"
        end.join
      end
    end
  end
end
