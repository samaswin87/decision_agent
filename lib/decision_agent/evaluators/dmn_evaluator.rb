require_relative "../dmn/adapter"
require_relative "../dmn/errors"
require_relative "base"
require_relative "json_rule_evaluator"

module DecisionAgent
  module Evaluators
    # Evaluates DMN decision models
    class DmnEvaluator < Base
      attr_reader :model, :decision_id

      def initialize(model:, decision_id:, name: nil)
        @model = model
        @decision_id = decision_id.to_s
        @name = name || "DmnEvaluator(#{@decision_id})"

        # Find and validate decision
        @decision = @model.find_decision(@decision_id)
        raise Dmn::InvalidDmnModelError, "Decision '#{@decision_id}' not found" unless @decision
        raise Dmn::InvalidDmnModelError, "Decision '#{@decision_id}' has no decision table" unless @decision.decision_table

        # Convert to JSON rules for execution
        adapter = Dmn::Adapter.new(@decision.decision_table)
        @rules_json = adapter.to_json_rules

        # Create internal JSON rule evaluator
        @json_evaluator = JsonRuleEvaluator.new(
          rules_json: @rules_json,
          name: @name
        )

        # Freeze for thread safety
        @model.freeze
        @decision_id.freeze
        @name.freeze
        freeze
      end

      def evaluate(context, feedback: {})
        hit_policy = @decision.decision_table.hit_policy

        # Collect explainability traces
        explainability_result = collect_explainability(context, hit_policy)

        # Short-circuit for FIRST and PRIORITY policies
        if %w[FIRST PRIORITY].include?(hit_policy)
          first_match = find_first_matching_evaluation(context, explainability_result: explainability_result)
          return first_match if first_match

          # If no match found, return nil (consistent with apply_first_policy behavior)
          return nil
        end

        # For UNIQUE, ANY, COLLECT - need all matches
        matching_evaluations = find_all_matching_evaluations(context, explainability_result: explainability_result)

        # Apply hit policy to select the appropriate evaluation
        result = apply_hit_policy(matching_evaluations)
        
        # Add explainability to metadata by creating new Evaluation with updated metadata
        if result && explainability_result
          metadata = result.metadata.dup
          metadata[:explainability] = explainability_result.to_h
          result = Evaluation.new(
            decision: result.decision,
            weight: result.weight,
            reason: result.reason,
            evaluator_name: result.evaluator_name,
            metadata: metadata
          )
        end
        
        result
      end

      private

      def evaluator_name
        @name
      end

      # Collect explainability traces for DMN evaluation
      def collect_explainability(context, hit_policy)
        ctx = context.is_a?(Context) ? context : Context.new(context)
        rules = @rules_json["rules"] || []
        rule_traces = []

        rules.each do |rule|
          rule_id = rule["id"] || "rule_#{rules.index(rule)}"
          if_clause = rule["if"]
          next unless if_clause

          # Create trace collector for this rule
          trace_collector = Explainability::TraceCollector.new

          # Evaluate condition with tracing
          matched = Dsl::ConditionEvaluator.evaluate(
            if_clause,
            ctx,
            trace_collector: trace_collector
          )

          then_clause = rule["then"] || {}
          rule_trace = Explainability::RuleTrace.new(
            rule_id: rule_id,
            matched: matched,
            condition_traces: trace_collector.traces,
            decision: then_clause["decision"],
            weight: then_clause["weight"],
            reason: then_clause["reason"]
          )

          rule_traces << rule_trace

          # Stop after first match for FIRST/PRIORITY policies (short-circuit evaluation)
          break if matched && %w[FIRST PRIORITY].include?(hit_policy)
        end

        Explainability::ExplainabilityResult.new(
          evaluator_name: @name,
          rule_traces: rule_traces
        )
      end

      # Find first matching rule (for short-circuiting)
      def find_first_matching_evaluation(context, explainability_result: nil, feedback: {})
        ctx = context.is_a?(Context) ? context : Context.new(context)
        rules = @rules_json["rules"] || []

        rules.each do |rule|
          if_clause = rule["if"]
          next unless if_clause

          # If explainability is already collected, use the trace data
          matched = if explainability_result
                     rule_trace = explainability_result.rule_traces.find { |rt| rt.rule_id == (rule["id"] || "rule_#{rules.index(rule)}") }
                     rule_trace&.matched
                   else
                     Dsl::ConditionEvaluator.evaluate(if_clause, ctx)
                   end

          next unless matched

          then_clause = rule["then"]
          metadata = {
            type: "dmn_rule",
            rule_id: rule["id"],
            ruleset: @rules_json["ruleset"],
            hit_policy: @decision.decision_table.hit_policy
          }
          
          # Add explainability data to metadata
          if explainability_result
            metadata[:explainability] = explainability_result.to_h
          end
          
          return Evaluation.new(
            decision: then_clause["decision"],
            weight: then_clause["weight"] || 1.0,
            reason: then_clause["reason"] || "Rule matched",
            evaluator_name: @name,
            metadata: metadata
          )
        end

        nil
      end

      # Find all matching rules (not just first)
      def find_all_matching_evaluations(context, explainability_result: nil, feedback: {})
        ctx = context.is_a?(Context) ? context : Context.new(context)
        rules = @rules_json["rules"] || []
        matching = []

        rules.each do |rule|
          if_clause = rule["if"]
          next unless if_clause

          # If explainability is already collected, use the trace data
          matched = if explainability_result
                     rule_trace = explainability_result.rule_traces.find { |rt| rt.rule_id == (rule["id"] || "rule_#{rules.index(rule)}") }
                     rule_trace&.matched
                   else
                     Dsl::ConditionEvaluator.evaluate(if_clause, ctx)
                   end

          next unless matched

          then_clause = rule["then"]
          metadata = {
            type: "dmn_rule",
            rule_id: rule["id"],
            ruleset: @rules_json["ruleset"],
            hit_policy: @decision.decision_table.hit_policy
          }
          
          # Add explainability data to metadata (will be added to final result)
          # For now, we'll add it to the final result after hit policy is applied
          
          matching << Evaluation.new(
            decision: then_clause["decision"],
            weight: then_clause["weight"] || 1.0,
            reason: then_clause["reason"] || "Rule matched",
            evaluator_name: @name,
            metadata: metadata
          )
        end

        matching
      end

      # Apply hit policy to matching evaluations
      def apply_hit_policy(matching_evaluations)
        hit_policy = @decision.decision_table.hit_policy

        case hit_policy
        when "UNIQUE"
          apply_unique_policy(matching_evaluations)
        when "FIRST"
          apply_first_policy(matching_evaluations)
        when "PRIORITY"
          apply_priority_policy(matching_evaluations)
        when "ANY"
          apply_any_policy(matching_evaluations)
        when "COLLECT"
          apply_collect_policy(matching_evaluations)
        else
          # Default to FIRST if unknown policy
          apply_first_policy(matching_evaluations)
        end
      end

      # UNIQUE: Exactly one rule must match
      def apply_unique_policy(matching_evaluations)
        case matching_evaluations.size
        when 0
          raise Dmn::InvalidDmnModelError,
                "UNIQUE hit policy requires exactly one matching rule, but none matched"
        when 1
          matching_evaluations.first
        else
          rule_ids = matching_evaluations.map { |e| e.metadata[:rule_id] }.join(", ")
          raise Dmn::InvalidDmnModelError,
                "UNIQUE hit policy requires exactly one matching rule, but #{matching_evaluations.size} matched: #{rule_ids}"
        end
      end

      # FIRST: Return first matching rule (already in order)
      def apply_first_policy(matching_evaluations)
        return nil if matching_evaluations.empty?

        matching_evaluations.first
      end

      # PRIORITY: Return rule with highest priority
      # For now, we use rule order as priority (first rule = highest priority)
      # In full DMN spec, outputs can have priority values defined
      def apply_priority_policy(matching_evaluations)
        return nil if matching_evaluations.empty?

        # For now, return first match (rules are already in priority order)
        # Future enhancement: check output priority values if defined
        matching_evaluations.first
      end

      # ANY: All matching rules must have same output
      def apply_any_policy(matching_evaluations)
        return nil if matching_evaluations.empty?

        # Check that all decisions are the same
        first_decision = matching_evaluations.first.decision
        all_same = matching_evaluations.all? { |e| e.decision == first_decision }

        unless all_same
          decisions = matching_evaluations.map(&:decision).uniq.join(", ")
          rule_ids = matching_evaluations.map { |e| e.metadata[:rule_id] }.join(", ")
          raise Dmn::InvalidDmnModelError,
                "ANY hit policy requires all matching rules to have the same output, " \
                "but found different outputs: #{decisions} (rules: #{rule_ids})"
        end

        matching_evaluations.first
      end

      # COLLECT: Return all matching rules
      # Since Evaluation expects a single decision, we'll return the first one
      # but include metadata about all matches
      def apply_collect_policy(matching_evaluations)
        return nil if matching_evaluations.empty?

        # Return first evaluation but include all matches in metadata
        first = matching_evaluations.first
        all_decisions = matching_evaluations.map(&:decision)
        all_rule_ids = matching_evaluations.map { |e| e.metadata[:rule_id] }

        Evaluation.new(
          decision: first.decision,
          weight: first.weight,
          reason: "COLLECT: #{matching_evaluations.size} rules matched",
          evaluator_name: @name,
          metadata: first.metadata.merge(
            collect_count: matching_evaluations.size,
            collect_decisions: all_decisions,
            collect_rule_ids: all_rule_ids
          )
        )
      end
    end
  end
end
