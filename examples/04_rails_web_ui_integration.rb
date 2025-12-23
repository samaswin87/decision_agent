#!/usr/bin/env ruby
# frozen_string_literal: true
# Example: Mounting DecisionAgent Web UI in Rails
#
# This example shows how to integrate the DecisionAgent Web UI
# into a Rails application as a Rack endpoint.

# ========================================
# Step 1: Add to Gemfile
# ========================================
#
# gem 'decision_agent'
#

# ========================================
# Step 2: Mount in config/routes.rb
# ========================================

# Basic mounting (no authentication)
# ----------------------------------
# require 'decision_agent/web/server'
#
# Rails.application.routes.draw do
#   mount DecisionAgent::Web::Server, at: '/decision_agent'
# end

# With Devise authentication
# ---------------------------
# require 'decision_agent/web/server'
#
# Rails.application.routes.draw do
#   authenticate :user, ->(user) { user.admin? } do
#     mount DecisionAgent::Web::Server, at: '/decision_agent'
#   end
# end

# With constraint-based authentication
# -------------------------------------
# require 'decision_agent/web/server'
#
# Rails.application.routes.draw do
#   constraints lambda { |request| request.env['warden'].user&.admin? } do
#     mount DecisionAgent::Web::Server, at: '/decision_agent'
#   end
# end

# ========================================
# Step 3 (Optional): Add HTTP Basic Auth
# ========================================
#
# Create config/initializers/decision_agent_web.rb
#
# DecisionAgent::Web::Server.class_eval do
#   use Rack::Auth::Basic, "Protected Area" do |username, password|
#     username == ENV['DECISION_AGENT_USERNAME'] &&
#     password == ENV['DECISION_AGENT_PASSWORD']
#   end
# end

# ========================================
# Example: Using DecisionAgent with Rails
# ========================================

require 'bundler/setup'
require 'decision_agent'

# Assuming you have a Rails model like this:
# class LoanApplication < ApplicationRecord
#   # attributes: amount, user_id, credit_score, income
# end

class LoanApprovalService
  def initialize
    @agent = DecisionAgent::Agent.new(
      evaluators: [loan_evaluator],
      audit_adapter: DecisionAgent::Audit::LoggerAdapter.new
    )
  end

  def evaluate_application(loan_application)
    context = {
      amount: loan_application.amount,
      credit_score: loan_application.credit_score,
      income: loan_application.income,
      applicant: {
        id: loan_application.user_id,
        verified: loan_application.user.verified?
      }
    }

    decision = @agent.decide(context: context)

    # Update the application status based on decision
    loan_application.update!(
      status: decision.decision,
      confidence: decision.confidence,
      decision_reason: decision.explanations.join('; ')
    )

    decision
  end

  private

  def loan_evaluator
    rules = {
      version: "1.0",
      ruleset: "loan_approval",
      rules: [
        {
          id: "auto_approve_low_amount",
          if: {
            all: [
              { field: "amount", op: "lt", value: 5000 },
              { field: "credit_score", op: "gte", value: 650 }
            ]
          },
          then: {
            decision: "approved",
            weight: 0.9,
            reason: "Low amount with good credit"
          }
        },
        {
          id: "high_earner_approval",
          if: {
            all: [
              { field: "income", op: "gte", value: 100000 },
              { field: "credit_score", op: "gte", value: 700 }
            ]
          },
          then: {
            decision: "approved",
            weight: 0.95,
            reason: "High income with excellent credit"
          }
        },
        {
          id: "review_medium_risk",
          if: {
            all: [
              { field: "amount", op: "gte", value: 5000 },
              { field: "amount", op: "lt", value: 50000 },
              { field: "credit_score", op: "gte", value: 600 },
              { field: "credit_score", op: "lt", value: 700 }
            ]
          },
          then: {
            decision: "manual_review",
            weight: 0.8,
            reason: "Medium amount with moderate credit requires review"
          }
        },
        {
          id: "reject_high_risk",
          if: {
            any: [
              { field: "credit_score", op: "lt", value: 550 },
              {
                all: [
                  { field: "amount", op: "gte", value: 50000 },
                  { field: "credit_score", op: "lt", value: 700 }
                ]
              }
            ]
          },
          then: {
            decision: "rejected",
            weight: 0.95,
            reason: "High risk - poor credit or large unqualified amount"
          }
        }
      ]
    }

    DecisionAgent::Evaluators::JsonRuleEvaluator.new(rules_json: rules)
  end
end

# ========================================
# Controller Example
# ========================================

# class LoanApplicationsController < ApplicationController
#   def create
#     @loan_application = LoanApplication.new(loan_params)
#
#     if @loan_application.save
#       # Evaluate using DecisionAgent
#       service = LoanApprovalService.new
#       decision = service.evaluate_application(@loan_application)
#
#       # Send notification based on decision
#       case decision.decision
#       when "approved"
#         ApprovalMailer.approved(@loan_application).deliver_later
#       when "rejected"
#         ApprovalMailer.rejected(@loan_application).deliver_later
#       when "manual_review"
#         AdminNotifier.review_needed(@loan_application).deliver_later
#       end
#
#       redirect_to @loan_application, notice: "Application submitted"
#     else
#       render :new
#     end
#   end
#
#   private
#
#   def loan_params
#     params.require(:loan_application).permit(:amount, :credit_score, :income)
#   end
# end

# ========================================
# Background Job Example
# ========================================

# class LoanEvaluationJob < ApplicationJob
#   queue_as :default
#
#   def perform(loan_application_id)
#     loan_application = LoanApplication.find(loan_application_id)
#     service = LoanApprovalService.new
#     service.evaluate_application(loan_application)
#   end
# end
#
# # Trigger from controller:
# LoanEvaluationJob.perform_later(@loan_application.id)

# ========================================
# Testing Example
# ========================================

# # spec/services/loan_approval_service_spec.rb
# require 'rails_helper'
#
# RSpec.describe LoanApprovalService do
#   let(:service) { described_class.new }
#
#   describe '#evaluate_application' do
#     it 'approves low amount with good credit' do
#       user = create(:user, verified: true)
#       app = create(:loan_application,
#         amount: 3000,
#         credit_score: 680,
#         income: 50000,
#         user: user
#       )
#
#       decision = service.evaluate_application(app)
#
#       expect(decision.decision).to eq('approved')
#       expect(app.reload.status).to eq('approved')
#     end
#
#     it 'rejects poor credit' do
#       user = create(:user, verified: false)
#       app = create(:loan_application,
#         amount: 10000,
#         credit_score: 500,
#         income: 40000,
#         user: user
#       )
#
#       decision = service.evaluate_application(app)
#
#       expect(decision.decision).to eq('rejected')
#       expect(app.reload.status).to eq('rejected')
#     end
#   end
# end

puts "Rails Web UI Integration Example"
puts "=" * 50
puts ""
puts "To mount DecisionAgent Web UI in your Rails app:"
puts ""
puts "1. Add to config/routes.rb:"
puts "   mount DecisionAgent::Web::Server, at: '/decision_agent'"
puts ""
puts "2. Start Rails server:"
puts "   rails server"
puts ""
puts "3. Visit the Web UI:"
puts "   http://localhost:3000/decision_agent"
puts ""
puts "See examples/04_rails_web_ui_integration.rb for complete examples"
