require_relative "lib/decision_agent/version"

Gem::Specification.new do |spec|
  spec.name          = "decision_agent"
  spec.version       = DecisionAgent::VERSION
  spec.authors       = ["Sam Aswin"]
  spec.email         = ["samaswin@gmail.com"]

  spec.summary       = "Deterministic, explainable, auditable decision engine for Ruby"
  spec.description   = "A production-grade decision agent that provides deterministic rule evaluation, conflict resolution, and full audit replay capabilities. Framework-agnostic and AI-optional."
  spec.homepage      = "https://github.com/samaswin/decision_agent"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/samaswin/decision_agent"
  spec.metadata["changelog_uri"] = "https://github.com/samaswin/decision_agent/blob/main/CHANGELOG.md"
  spec.metadata["github_repo"] = "https://github.com/samaswin/decision_agent"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{lib,spec,bin}/**/*") + %w[README.md LICENSE.txt]
  spec.bindir = "bin"
  spec.executables = ["decision_agent"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "bcrypt", "~> 3.1"
  spec.add_dependency "json-canonicalization", "~> 1.0"
  spec.add_dependency "nokogiri", "~> 1.15" # For DMN XML parsing
  spec.add_dependency "parslet", "~> 2.0" # For FEEL expression parsing
  spec.add_dependency "roo", "~> 2.10"
  spec.add_dependency "rubyzip", "< 3.0.0" # Restrict to 2.x to avoid RubyZip 3.0 API changes
  spec.add_dependency "sinatra", "~> 3.0"

  # Optional dependencies for Rails integration
  # spec.add_dependency "activerecord", "~> 7.0"  # Uncomment when using with Rails

  # Development dependencies
  spec.add_development_dependency "rack-test", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "webmock", "~> 3.18" # For HTTP request mocking in tests
end
