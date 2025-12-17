require_relative "lib/decision_agent/version"

Gem::Specification.new do |spec|
  spec.name          = "decision_agent"
  spec.version       = DecisionAgent::VERSION
  spec.authors       = ["Decision Agent Team"]
  spec.email         = ["team@decisionagent.dev"]

  spec.summary       = "Deterministic, explainable, auditable decision engine for Ruby"
  spec.description   = "A production-grade decision agent that provides deterministic rule evaluation, conflict resolution, and full audit replay capabilities. Framework-agnostic and AI-optional."
  spec.homepage      = "https://github.com/decision-agent/decision_agent"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/decision-agent/decision_agent"
  spec.metadata["changelog_uri"] = "https://github.com/decision-agent/decision_agent/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{lib,spec}/**/*") + %w[README.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end
