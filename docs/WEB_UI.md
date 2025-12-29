# DecisionAgent Web UI - Rule Builder

A user-friendly web interface for creating and managing DecisionAgent rules without writing JSON manually.

## Overview

The DecisionAgent Web UI provides a visual rule builder that allows non-technical users to create, edit, validate, and export decision rules. The interface includes:

- **Visual Rule Builder**: Create rules using forms and dropdowns
- **Condition Builder**: Build complex nested conditions (all/any/field)
- **Real-time Validation**: Validate rules against the DecisionAgent schema
- **JSON Export/Import**: Download or copy rules as JSON
- **Example Templates**: Pre-built rule sets to get started quickly

## Quick Start

### 1. Install the Gem

```bash
gem install decision_agent
```

Or add to your Gemfile:

```ruby
gem 'decision_agent'
```

### 2. Launch the Web UI

```bash
decision_agent web
```

This will start the web server on `http://localhost:4567`

To use a different port:

```bash
decision_agent web 8080
```

### 3. Open in Browser

Navigate to [http://localhost:4567](http://localhost:4567) in your web browser.

## Features

### Visual Rule Builder

The left panel contains the rule builder interface:

1. **Ruleset Information**
   - Version: The schema version (default: "1.0")
   - Ruleset Name: A descriptive name for your rule set

2. **Rules List**
   - View all created rules
   - Edit or delete individual rules
   - See a summary of each rule's conditions

3. **Actions**
   - Validate: Check rules against the schema
   - Clear All: Remove all rules

### Rule Editor Modal

When creating or editing a rule, a modal dialog allows you to:

#### Rule ID
Every rule needs a unique identifier (e.g., `high_priority_approval`)

#### Condition Builder (IF clause)

Build conditions using three types:

**Field Condition**: Compare a field value
- Field path: Use dot notation (e.g., `user.role`, `request.amount`)
- Operator: Choose from:
  - `equals (==)`: Exact match
  - `not equals (!=)`: Not equal
  - `greater than (>)`: Numeric comparison
  - `greater or equal (>=)`: Numeric comparison
  - `less than (<)`: Numeric comparison
  - `less or equal (<=)`: Numeric comparison
  - `in array`: Value is in an array
  - `is present`: Field exists and is not empty
  - `is blank`: Field is missing or empty
- Value: The value to compare (not needed for `is present` and `is blank`)

**All (AND)**: All subconditions must be true
- Click "+ Add Condition" to add subconditions
- Can nest other All/Any/Field conditions

**Any (OR)**: At least one subcondition must be true
- Click "+ Add Condition" to add subconditions
- Can nest other All/Any/Field conditions

#### Then Clause (Action)

Define what happens when the condition matches:

- **Decision** (required): The decision to make (e.g., "approve", "reject", "manual_review")
- **Weight** (optional): Confidence weight between 0.0 and 1.0 (default: 0.8)
- **Reason** (optional): Human-readable explanation

### JSON Preview Panel

The right panel shows:

1. **JSON Output**: Live preview of your rules in JSON format
2. **Actions**:
   - **Copy**: Copy JSON to clipboard
   - **Download**: Download as a `.json` file
   - **Import**: Load rules from a JSON file

3. **Validation Status**: Shows validation results
   - ✓ Success: All rules are valid
   - ✗ Errors: Shows specific validation errors with helpful messages

## Example Workflows

### Creating a Simple Rule

1. Click "Add Rule"
2. Enter Rule ID: `admin_auto_approve`
3. Set condition:
   - Field: `user.role`
   - Operator: `equals (==)`
   - Value: `admin`
4. Set action:
   - Decision: `approve`
   - Weight: `0.95`
   - Reason: `Admin user has automatic approval`
5. Click "Save Rule"
6. Click "Validate Rules"

### Creating Complex Nested Conditions

For rules like "Approve if (user is admin OR manager) AND amount is less than $10,000":

1. Click "Add Rule"
2. Enter Rule ID: `complex_approval`
3. Change condition type to "All (AND)"
4. Click "+ Add Condition" in the All block
5. First subcondition:
   - Change type to "Any (OR)"
   - Add two field conditions:
     - `user.role` equals `admin`
     - `user.role` equals `manager`
6. Second subcondition (field):
   - `amount` less than `10000`
7. Set action:
   - Decision: `approve`
   - Weight: `0.85`
   - Reason: `Admin or manager with amount under limit`
8. Click "Save Rule"

### Loading Example Rules

Click "Load Example" to populate the builder with a sample approval workflow containing:
- High priority auto-approval
- Low amount approval
- Missing information rejection

You can edit these examples to understand the structure and create your own rules.

### Importing Existing Rules

1. Click "Import" (📁 icon)
2. Select a `.json` file with DecisionAgent rules
3. Rules will be loaded into the builder

### Exporting Rules

1. Create or edit your rules
2. Click "Validate Rules" to ensure they're correct
3. Click "Copy" (📋) to copy JSON to clipboard, or
4. Click "Download" (⬇) to save as a file

## Validation

The Web UI validates rules using the same SchemaValidator that DecisionAgent uses internally. Validation checks:

- ✅ Required fields (`id`, `if`, `then`)
- ✅ Valid operators
- ✅ Proper structure for `all`/`any` conditions
- ✅ Dot notation syntax
- ✅ Weight and reason formatting
- ✅ Nested condition depth

Validation errors are displayed with:
- Line numbers and field paths (e.g., `rules[0].if`)
- Helpful suggestions for fixing errors
- Links to documentation

## CLI Commands

The DecisionAgent CLI provides these commands:

### Start Web UI

```bash
# Default port (4567)
decision_agent web

# Custom port
decision_agent web 8080
```

### Validate Rules File

```bash
decision_agent validate rules.json
```

Output:
```
🔍 Validating rules.json...
✅ Validation successful!
   Version: 1.0
   Ruleset: my_ruleset
   Rules: 3
```

### Show Version

```bash
decision_agent version
```

### Show Help

```bash
decision_agent help
```

## API Endpoints

The web server exposes these endpoints:

### POST /api/validate

Validate a ruleset.

**Request:**
```json
{
  "version": "1.0",
  "ruleset": "my_rules",
  "rules": [...]
}
```

**Response (Success):**
```json
{
  "valid": true,
  "message": "Rules are valid!"
}
```

**Response (Error):**
```json
{
  "valid": false,
  "errors": [
    "rules[0]: Missing required field 'id'",
    "rules[1].if: Unsupported operator 'invalid_op'"
  ]
}
```

### POST /api/evaluate

Test rule evaluation with a context (optional feature).

**Request:**
```json
{
  "rules": {
    "version": "1.0",
    "ruleset": "test",
    "rules": [...]
  },
  "context": {
    "user": { "role": "admin" },
    "amount": 500
  }
}
```

**Response:**
```json
{
  "success": true,
  "decision": "approve",
  "weight": 0.8,
  "reason": "Admin user",
  "evaluator_name": "JsonRuleEvaluator",
  "metadata": { "rule_id": "admin_auto_approve" }
}
```

### GET /api/examples

Get pre-built example rulesets.

**Response:**
```json
[
  {
    "name": "Approval Workflow",
    "description": "Basic approval rules",
    "rules": { ... }
  },
  ...
]
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

## Programmatic Usage

You can also start the web server programmatically:

```ruby
require 'decision_agent'
require 'decision_agent/web/server'

# Start on default port (4567)
DecisionAgent::Web::Server.start!

# Start on custom port
DecisionAgent::Web::Server.start!(port: 8080, host: "0.0.0.0")
```

## Architecture

The Web UI consists of:

- **Frontend**: Vanilla JavaScript SPA (no framework dependencies)
  - `index.html`: Main UI structure
  - `styles.css`: Modern, responsive styling
  - `app.js`: Rule builder logic

- **Backend**: Sinatra web server
  - Serves static files
  - Validates rules using DecisionAgent::Dsl::SchemaValidator
  - Provides REST API

## Browser Support

The Web UI works in all modern browsers:
- Chrome/Edge 90+
- Firefox 88+
- Safari 14+

## Troubleshooting

### Port Already in Use

If port 4567 is already in use:

```bash
decision_agent web 8080
```

### Rules Not Validating

Check the validation errors in the right panel. Common issues:
- Missing required fields
- Invalid operator names (check spelling)
- Malformed dot notation (e.g., `field..nested`)
- Weight outside 0.0-1.0 range

### Cannot Import JSON

Ensure your JSON file:
- Is valid JSON syntax
- Contains a `rules` array at the root level
- Follows the DecisionAgent schema

## Security Considerations

**Important**: The Web UI is designed for **local development and rule creation**. It is **NOT intended for production deployment** without additional security measures:

- No authentication/authorization
- No rate limiting
- Binds to 0.0.0.0 by default (accessible from network)

For production rule management, consider:
- Adding authentication (BasicAuth, OAuth, etc.)
- Running behind a reverse proxy (nginx, Apache)
- Implementing rate limiting
- Using HTTPS
- Restricting network access

## Development

To modify the Web UI:

1. Edit files in `lib/decision_agent/web/public/`
   - `index.html`: Structure
   - `styles.css`: Styling
   - `app.js`: Logic

2. Edit server in `lib/decision_agent/web/server.rb`

3. Restart the server to see changes:
   ```bash
   decision_agent web
   ```

## Contributing

We welcome contributions to improve the Web UI:

- UI/UX improvements
- New features (rule templates, bulk import, etc.)
- Bug fixes
- Documentation improvements

Please submit pull requests to the main repository.

## License

Same as DecisionAgent - MIT License

## Support

For issues or questions:
- GitHub Issues: https://github.com/samaswin87/decision_agent/issues
- Documentation: See main README.md
