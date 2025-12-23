require 'spec_helper'
require 'rack/test'
require_relative '../lib/decision_agent/web/server'

RSpec.describe 'DecisionAgent Web UI Rack Integration' do
  include Rack::Test::Methods

  def app
    DecisionAgent::Web::Server
  end

  describe 'Rack interface' do
    it 'responds to .call for Rack compatibility' do
      expect(DecisionAgent::Web::Server).to respond_to(:call)
    end

    it 'serves the main page' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('DecisionAgent')
    end

    it 'serves the health endpoint' do
      get '/health'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['version']).to eq(DecisionAgent::VERSION)
    end

    it 'validates rules via POST /api/validate' do
      valid_rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "test_rule",
          if: { field: "amount", op: "gt", value: 100 },
          then: { decision: "approve", weight: 0.9, reason: "Test" }
        }]
      }

      post '/api/validate', valid_rules.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['valid']).to be true
    end

    it 'returns error for invalid rules' do
      invalid_rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "bad_rule"
          # Missing required fields
        }]
      }

      post '/api/validate', invalid_rules.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(422)
      json = JSON.parse(last_response.body)
      expect(json['valid']).to be false
      expect(json['errors']).to be_an(Array)
    end

    it 'evaluates rules via POST /api/evaluate' do
      rules = {
        version: "1.0",
        ruleset: "test_rules",
        rules: [{
          id: "high_value",
          if: { field: "amount", op: "gt", value: 1000 },
          then: { decision: "approve", weight: 0.9, reason: "High value" }
        }]
      }

      payload = {
        rules: rules,
        context: { amount: 1500 }
      }

      post '/api/evaluate', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
      expect(json['decision']).to eq('approve')
      expect(json['weight']).to eq(0.9)
      expect(json['reason']).to eq('High value')
    end

    it 'serves example rules' do
      get '/api/examples'

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_an(Array)
      expect(json.length).to be > 0
      expect(json.first).to have_key('name')
      expect(json.first).to have_key('rules')
    end

    it 'handles CORS preflight requests' do
      options '/api/validate'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(last_response.headers['Access-Control-Allow-Methods']).to include('POST')
    end
  end

  describe 'Rails mounting compatibility' do
    it 'can be mounted in a Rack app' do
      # Simulate a Rails-style mount
      rack_app = Rack::Builder.new do
        map '/decision_agent' do
          run DecisionAgent::Web::Server
        end
      end

      # Create a test session for the mounted app
      test_session = Rack::Test::Session.new(Rack::MockSession.new(rack_app))

      # Test that the health endpoint works when mounted
      test_session.get '/decision_agent/health'
      expect(test_session.last_response).to be_ok

      json = JSON.parse(test_session.last_response.body)
      expect(json['status']).to eq('ok')
    end
  end
end
