module DecisionAgent
  # Semantic version: MAJOR.MINOR.PATCH
  # MAJOR: Incremented for incompatible API changes
  # MINOR: Incremented for backward-compatible functionality additions
  # PATCH: Incremented for backward-compatible bug fixes
  VERSION = "1.1.0".freeze

  # Validate version format (semantic versioning)
  unless VERSION.match?(/\A\d+\.\d+\.\d+(-[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*)?(\+[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*)?\z/)
    raise ArgumentError, "Invalid version format: #{VERSION}. Must follow semantic versioning (MAJOR.MINOR.PATCH)"
  end
end
