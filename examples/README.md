# DecisionAgent Versioning Examples

This directory contains practical examples demonstrating how to use the DecisionAgent versioning system.

## Examples Overview

### 1. Basic Versioning ([01_basic_versioning.rb](01_basic_versioning.rb))

**What it covers:**
- Creating initial versions
- Updating rules and creating new versions
- Adding new rules
- Listing all versions
- Comparing versions
- Rolling back to previous versions
- Getting version history
- Retrieving active versions

**Run it:**
```bash
ruby examples/01_basic_versioning.rb
```

**Best for:** First-time users, understanding core concepts

---

### 2. Rails Integration ([02_rails_integration.rb](02_rails_integration.rb))

**What it covers:**
- Rails controller implementation
- ActiveRecord model usage
- Routes configuration
- Service objects for versioning
- Background jobs for cleanup
- Rails console examples

**Setup:**
```bash
# In your Rails app
rails generate decision_agent:install
rails db:migrate
```

**Best for:** Rails developers integrating versioning into their apps

---

### 3. Sinatra Application ([03_sinatra_app.rb](03_sinatra_app.rb))

**What it covers:**
- Complete Sinatra app with versioning API
- RESTful endpoints
- CORS configuration
- Error handling
- Rule evaluation with active versions
- curl examples for testing

**Run it:**
```bash
ruby examples/03_sinatra_app.rb
# Visit http://localhost:4567
```

**Test with curl:**
```bash
# Create version
curl -X POST http://localhost:4567/rules/test_001/versions \
  -H "Content-Type: application/json" \
  -d '{"content": {...}, "created_by": "user@example.com"}'

# List versions
curl http://localhost:4567/rules/test_001/versions

# Get history
curl http://localhost:4567/rules/test_001/history
```

**Best for:** Building standalone versioning APIs

---

### 4. Advanced Scenarios ([04_advanced_scenarios.rb](04_advanced_scenarios.rb))

**What it covers:**
- Multi-environment versioning (dev/staging/prod)
- A/B testing with different versions
- Canary deployments and gradual rollouts
- Version tagging and metadata
- Batch operations
- Audit trails and compliance
- Critical rule protection

**Run it:**
```bash
ruby examples/04_advanced_scenarios.rb
```

**Best for:** Production deployments, enterprise use cases

---

## Common Use Cases

### Use Case 1: Compliance and Audit Requirements

```ruby
require 'decision_agent'

manager = DecisionAgent::Versioning::VersionManager.new

# Create auditable version
version = manager.save_version(
  rule_id: "compliance_rule_001",
  rule_content: rules,
  created_by: "compliance_officer@company.com",
  changelog: "SOX-2024-Q1: Updated threshold per audit requirements"
)

# Generate audit report
history = manager.get_history(rule_id: "compliance_rule_001")
puts "Total changes: #{history[:total_versions]}"
puts "Last modified: #{history[:updated_at]}"
history[:versions].each do |v|
  puts "v#{v[:version_number]}: #{v[:changelog]} by #{v[:created_by]}"
end
```

### Use Case 2: Emergency Rollback

```ruby
# Something went wrong in production!
# Quickly rollback to last known good version

# Find the last known good version
versions = manager.get_versions(rule_id: "production_rules")
last_good = versions.find { |v| v[:changelog].include?("TESTED") }

# Rollback
manager.rollback(
  version_id: last_good[:id],
  performed_by: "oncall_engineer@company.com"
)

# Alert team
puts "ROLLBACK: Reverted to v#{last_good[:version_number]}"
```

### Use Case 3: Feature Flags with Versions

```ruby
# Use versions as feature flags
def get_rules_for_user(user)
  if user.beta_tester?
    # Beta users get the latest version
    manager.get_active_version(rule_id: "features_beta")
  else
    # Regular users get stable version
    manager.get_version_by_number(
      rule_id: "features_stable",
      version_number: 10  # Known stable version
    )
  end
end
```

### Use Case 4: Testing Rule Changes

```ruby
# Test new rules without affecting production
test_manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: DecisionAgent::Versioning::FileStorageAdapter.new(
    storage_path: './test_versions'
  )
)

# Create test version
test_version = test_manager.save_version(
  rule_id: "test_rules",
  rule_content: new_experimental_rules,
  created_by: "qa_team",
  changelog: "Testing new fraud detection algorithm"
)

# Run tests
run_test_suite(test_version[:content])

# If tests pass, promote to production
if tests_passed?
  prod_manager.save_version(
    rule_id: "fraud_rules",
    rule_content: test_version[:content],
    created_by: "qa_team",
    changelog: "Promoted from test - All tests passed"
  )
end
```

## Running the Examples

### Prerequisites

```bash
# Install the gem (development mode)
bundle install

# Or install from rubygems
gem install decision_agent
```

### File-Based Storage (Default)

All examples use file-based storage by default. Versions are stored in:
- `./versions/` (basic examples)
- `./data/versions/` (Sinatra app)
- Custom paths as configured

### Rails with ActiveRecord

For Rails examples:

1. Generate models:
```bash
rails generate decision_agent:install
```

2. Run migrations:
```bash
rails db:migrate
```

3. The VersionManager will auto-detect ActiveRecord

## Testing Your Integration

### Quick Test Script

```ruby
#!/usr/bin/env ruby
require 'decision_agent'

# Create manager
manager = DecisionAgent::Versioning::VersionManager.new

# Test data
rules = {
  version: "1.0",
  ruleset: "test",
  rules: [{
    id: "test_rule",
    if: { field: "test", op: "eq", value: true },
    then: { decision: "pass", weight: 1.0, reason: "Test" }
  }]
}

# Save
v1 = manager.save_version(
  rule_id: "test_001",
  rule_content: rules,
  created_by: "tester"
)

puts "✓ Saved version #{v1[:version_number]}"

# Load
loaded = manager.get_version(version_id: v1[:id])
puts "✓ Loaded version successfully"

# Verify
if loaded[:content] == rules
  puts "✅ All tests passed!"
else
  puts "❌ Test failed - content mismatch"
end
```

## Performance Considerations

### File Storage
- **Good for:** Development, small deployments, < 1000 versions
- **Limitations:** Not suitable for high concurrency
- **Tip:** Use limit parameter when listing versions

### ActiveRecord Storage
- **Good for:** Production, high concurrency, > 1000 versions
- **Optimizations:**
  - Index on `rule_id` and `status`
  - Paginate results in UI
  - Archive old versions periodically

## Troubleshooting

### "Version not found"
- Check if rule_id is correct
- Verify version was successfully saved
- Check storage path permissions (file storage)

### "Validation Error"
- Ensure rule_content is a valid hash
- Content cannot be nil or empty
- Verify JSON structure if parsing from string

### "ActiveRecord not found"
- Run the generator: `rails generate decision_agent:install`
- Run migrations: `rails db:migrate`
- Ensure models are loaded in Rails app

## Next Steps

1. **Start with Example 1** - Understand the basics
2. **Choose your framework** - Rails (Example 2) or Sinatra (Example 3)
3. **Explore advanced features** - Example 4 for production patterns
4. **Read the full docs** - [VERSIONING.md](../wiki/VERSIONING.md)

## Support

- Documentation: [VERSIONING.md](../wiki/VERSIONING.md)
- API Reference: [VERSIONING.md#api-reference](../wiki/VERSIONING.md#api-reference)
- Issues: [GitHub Issues](https://github.com/samaswin87/decision_agent/issues)

## License

These examples are part of the DecisionAgent gem - MIT License
