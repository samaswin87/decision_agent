#!/usr/bin/env ruby
# frozen_string_literal: true
# Example 3: Complete Sinatra Application with Versioning
#
# This example demonstrates how to build a complete Sinatra app
# with rule versioning capabilities.
#
# Run: ruby examples/03_sinatra_app.rb
# Visit: http://localhost:4567

require 'bundler/setup'
require 'sinatra/base'
require 'json'
require 'decision_agent'

class RuleVersioningApp < Sinatra::Base
  set :port, 4567
  set :bind, '0.0.0.0'

  # Initialize version manager
  configure do
    set :version_manager, DecisionAgent::Versioning::VersionManager.new(
      adapter: DecisionAgent::Versioning::FileStorageAdapter.new(
        storage_path: './data/versions'
      )
    )
  end

  # Enable CORS
  before do
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type'
  end

  options '*' do
    200
  end

  # ========================================
  # Routes
  # ========================================

  # Home page
  get '/' do
    content_type :json
    {
      name: "Rule Versioning API",
      version: DecisionAgent::VERSION,
      endpoints: {
        rules: {
          create_version: "POST /rules/:rule_id/versions",
          list_versions: "GET /rules/:rule_id/versions",
          get_version: "GET /versions/:version_id",
          activate: "POST /versions/:version_id/activate",
          compare: "GET /versions/:v1/compare/:v2",
          history: "GET /rules/:rule_id/history"
        },
        evaluation: {
          evaluate: "POST /evaluate"
        }
      }
    }.to_json
  end

  # Create a new version
  post '/rules/:rule_id/versions' do
    content_type :json

    begin
      data = JSON.parse(request.body.read, symbolize_names: true)

      version = settings.version_manager.save_version(
        rule_id: params[:rule_id],
        rule_content: data[:content],
        created_by: data[:created_by] || 'api_user',
        changelog: data[:changelog]
      )

      status 201
      version.to_json

    rescue DecisionAgent::ValidationError => e
      status 422
      { error: 'Validation failed', message: e.message }.to_json

    rescue JSON::ParserError => e
      status 400
      { error: 'Invalid JSON', message: e.message }.to_json

    rescue => e
      status 500
      { error: 'Internal error', message: e.message }.to_json
    end
  end

  # List versions for a rule
  get '/rules/:rule_id/versions' do
    content_type :json

    begin
      limit = params[:limit]&.to_i

      versions = settings.version_manager.get_versions(
        rule_id: params[:rule_id],
        limit: limit
      )

      versions.to_json

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Get version history with metadata
  get '/rules/:rule_id/history' do
    content_type :json

    begin
      history = settings.version_manager.get_history(rule_id: params[:rule_id])
      history.to_json

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Get specific version
  get '/versions/:version_id' do
    content_type :json

    begin
      version = settings.version_manager.get_version(version_id: params[:version_id])

      if version
        version.to_json
      else
        status 404
        { error: 'Version not found' }.to_json
      end

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Activate a version (rollback)
  post '/versions/:version_id/activate' do
    content_type :json

    begin
      data = request.body.read
      parsed_data = data.empty? ? {} : JSON.parse(data, symbolize_names: true)

      version = settings.version_manager.rollback(
        version_id: params[:version_id],
        performed_by: parsed_data[:performed_by] || 'api_user'
      )

      version.to_json

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Compare two versions
  get '/versions/:v1/compare/:v2' do
    content_type :json

    begin
      comparison = settings.version_manager.compare(
        version_id_1: params[:v1],
        version_id_2: params[:v2]
      )

      if comparison
        comparison.to_json
      else
        status 404
        { error: 'One or both versions not found' }.to_json
      end

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Evaluate rules (bonus feature)
  post '/evaluate' do
    content_type :json

    begin
      data = JSON.parse(request.body.read, symbolize_names: true)

      # Get active version
      active_version = settings.version_manager.get_active_version(
        rule_id: data[:rule_id]
      )

      unless active_version
        status 404
        return { error: 'No active version found for this rule' }.to_json
      end

      # Create evaluator with the active version's rules
      evaluator = DecisionAgent::Evaluators::JsonRuleEvaluator.new(
        rules_json: active_version[:content]
      )

      # Evaluate
      context = DecisionAgent::Context.new(data[:context] || {})
      result = evaluator.evaluate(context)

      if result
        {
          success: true,
          decision: result.decision,
          weight: result.weight,
          reason: result.reason,
          version: active_version[:version_number],
          metadata: result.metadata
        }.to_json
      else
        {
          success: true,
          decision: nil,
          message: 'No rules matched',
          version: active_version[:version_number]
        }.to_json
      end

    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Health check
  get '/health' do
    content_type :json
    {
      status: 'ok',
      version: DecisionAgent::VERSION,
      timestamp: Time.now.utc.iso8601
    }.to_json
  end

  # Start the server
  run! if app_file == $0
end

# ========================================
# Usage Examples (via curl)
# ========================================

__END__

# 1. Create a version
curl -X POST http://localhost:4567/rules/approval_001/versions \
  -H "Content-Type: application/json" \
  -d '{
    "content": {
      "version": "1.0",
      "ruleset": "approval",
      "rules": [{
        "id": "rule_1",
        "if": {"field": "amount", "op": "lt", "value": 1000},
        "then": {"decision": "approve", "weight": 0.9, "reason": "Low amount"}
      }]
    },
    "created_by": "john@example.com",
    "changelog": "Initial version"
  }'

# 2. List versions
curl http://localhost:4567/rules/approval_001/versions

# 3. Get history
curl http://localhost:4567/rules/approval_001/history

# 4. Get specific version
curl http://localhost:4567/versions/approval_001_v1

# 5. Activate version (rollback)
curl -X POST http://localhost:4567/versions/approval_001_v1/activate \
  -H "Content-Type: application/json" \
  -d '{"performed_by": "admin@example.com"}'

# 6. Compare versions
curl http://localhost:4567/versions/approval_001_v1/compare/approval_001_v2

# 7. Evaluate with active version
curl -X POST http://localhost:4567/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "rule_id": "approval_001",
    "context": {
      "amount": 500,
      "user_type": "premium"
    }
  }'

# 8. Health check
curl http://localhost:4567/health
