# Web UI Setup & Testing Guide

## What Was Added

The DecisionAgent gem now includes a complete web-based visual rule builder for non-technical users.

### Files Created

```
decision_agent/
├── bin/
│   └── decision_agent              # CLI executable
├── lib/
│   └── decision_agent/
│       └── web/
│           ├── public/
│           │   ├── index.html      # Main UI
│           │   ├── styles.css      # Styling
│           │   └── app.js          # JavaScript app
│           └── server.rb           # Sinatra web server
└── WEB_UI.md                       # Complete documentation
```

### Features

✅ **Visual Rule Builder**
- Create rules using forms and dropdowns
- No JSON knowledge required
- Nested conditions (all/any/field)
- Real-time validation

✅ **CLI Commands**
- `decision_agent web` - Start web UI
- `decision_agent validate FILE` - Validate rules file
- `decision_agent version` - Show version
- `decision_agent help` - Show help

✅ **API Endpoints**
- `POST /api/validate` - Validate rules
- `POST /api/evaluate` - Test rule evaluation
- `GET /api/examples` - Get example rules
- `GET /health` - Health check

✅ **Import/Export**
- Copy JSON to clipboard
- Download as .json file
- Import existing rule files
- Load example templates

## Quick Test

### 1. Install Dependencies

First, install Sinatra:

```bash
cd /Users/ashwin.raj/git/internal/decision_agent
bundle add sinatra
```

Or manually add to Gemfile:

```ruby
gem 'sinatra', '~> 3.0'
```

Then run:

```bash
bundle install
```

### 2. Test the CLI

```bash
# Make sure the executable is accessible
bundle exec bin/decision_agent help
```

You should see:

```
DecisionAgent CLI

Usage:
  decision_agent [command] [options]

Commands:
  web [PORT]         Start the web UI rule builder
  validate FILE      Validate a rules JSON file
  version            Show version
  help               Show this help message
...
```

### 3. Start the Web UI

```bash
bundle exec bin/decision_agent web
```

You should see:

```
🎯 Starting DecisionAgent Rule Builder...
📍 Server: http://localhost:4567
⚡️ Press Ctrl+C to stop
```

### 4. Open in Browser

Navigate to [http://localhost:4567](http://localhost:4567)

You should see:
- Header: "🎯 DecisionAgent Rule Builder"
- Left panel: Rule Configuration
- Right panel: JSON Output
- "Load Example" button

### 5. Test Rule Creation

1. Click "Load Example"
2. You should see 3 pre-loaded rules
3. Click "Validate Rules"
4. You should see: "✓ All rules are valid!"

### 6. Test Rule Validation

Create a test file:

```bash
cat > test_rules.json << 'EOF'
{
  "version": "1.0",
  "ruleset": "test",
  "rules": [
    {
      "id": "test_rule",
      "if": { "field": "status", "op": "eq", "value": "active" },
      "then": { "decision": "approve", "weight": 0.8 }
    }
  ]
}
EOF
```

Validate it:

```bash
bundle exec bin/decision_agent validate test_rules.json
```

You should see:

```
🔍 Validating test_rules.json...
✅ Validation successful!
   Version: 1.0
   Ruleset: test
   Rules: 1
```

## API Testing

### Test Validation Endpoint

```bash
curl -X POST http://localhost:4567/api/validate \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.0",
    "ruleset": "test",
    "rules": [
      {
        "id": "test",
        "if": { "field": "status", "op": "eq", "value": "active" },
        "then": { "decision": "approve" }
      }
    ]
  }'
```

Expected response:

```json
{
  "valid": true,
  "message": "Rules are valid!"
}
```

### Test Evaluation Endpoint

```bash
curl -X POST http://localhost:4567/api/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "rules": {
      "version": "1.0",
      "ruleset": "test",
      "rules": [
        {
          "id": "admin_approval",
          "if": { "field": "user.role", "op": "eq", "value": "admin" },
          "then": { "decision": "approve", "weight": 0.9, "reason": "Admin user" }
        }
      ]
    },
    "context": {
      "user": { "role": "admin" }
    }
  }'
```

Expected response:

```json
{
  "success": true,
  "decision": "approve",
  "weight": 0.9,
  "reason": "Admin user",
  "evaluator_name": "JsonRuleEvaluator",
  "metadata": { "rule_id": "admin_approval" }
}
```

### Test Examples Endpoint

```bash
curl http://localhost:4567/api/examples
```

You should get an array of 3 example rulesets.

### Test Health Check

```bash
curl http://localhost:4567/health
```

Expected:

```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

## Troubleshooting

### "Cannot load such file -- sinatra"

Install Sinatra:

```bash
bundle add sinatra
# or
gem install sinatra
```

### Port 4567 Already in Use

Use a different port:

```bash
bundle exec bin/decision_agent web 8080
```

### "Permission denied" Error

Make the CLI executable:

```bash
chmod +x bin/decision_agent
```

### Web UI Not Loading

1. Check server is running (look for startup message)
2. Try accessing http://127.0.0.1:4567 instead
3. Check firewall settings

## Integration Testing

### Test in Your Gemfile

Add to your application's Gemfile:

```ruby
gem 'decision_agent', path: '/Users/ashwin.raj/git/internal/decision_agent'
```

Then:

```bash
bundle install
bundle exec decision_agent web
```

### Test After Publishing

Once published to RubyGems:

```bash
gem install decision_agent
decision_agent web
```

## Next Steps

1. **Run all existing tests** to ensure nothing broke:
   ```bash
   bundle exec rspec
   ```

2. **Test in different browsers**:
   - Chrome
   - Firefox
   - Safari
   - Edge

3. **Test on different platforms**:
   - macOS
   - Linux
   - Windows (via WSL)

4. **Consider adding tests** for the web UI:
   - Sinatra endpoint tests
   - JavaScript unit tests (optional)

## Documentation

- Main README: Updated with Web UI section
- Detailed docs: [WEB_UI.md](WEB_UI.md)
- This setup guide: WEB_UI_SETUP.md

## Updates Made

### decision_agent.gemspec
- Added Sinatra dependency
- Added bin directory to files
- Added executables

### README.md
- Added Web UI section after Installation
- Updated roadmap (marked Web UI as complete)

### New Files
- `lib/decision_agent/web/server.rb` - Sinatra app
- `lib/decision_agent/web/public/index.html` - UI
- `lib/decision_agent/web/public/styles.css` - Styling
- `lib/decision_agent/web/public/app.js` - JavaScript
- `bin/decision_agent` - CLI executable
- `WEB_UI.md` - Documentation
- `WEB_UI_SETUP.md` - This file

## Success Criteria

✅ CLI launches without errors
✅ Web UI loads in browser
✅ Can create rules visually
✅ Validation works correctly
✅ Export/Import functions work
✅ All API endpoints respond correctly
✅ Existing RSpec tests still pass

Enjoy your new Web UI! 🎉
