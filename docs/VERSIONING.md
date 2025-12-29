# Rule Versioning System

DecisionAgent includes a comprehensive versioning system for tracking rule changes, enabling rollbacks, and comparing versions. The system is **framework-agnostic** and supports both Rails (with ActiveRecord) and standalone deployments.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Web UI](#web-ui)
- [API Reference](#api-reference)
- [Storage Adapters](#storage-adapters)

## Features

✅ **Auto-versioning** - Automatically create versions on every rule save
✅ **Version History** - List all versions for a rule with metadata
✅ **Version Comparison** - Diff two versions to see changes
✅ **Rollback** - Activate any previous version
✅ **Framework-Agnostic** - Works with Rails, Sinatra, or any Ruby framework
✅ **Pluggable Storage** - File-based or database-backed storage
✅ **Audit Trail** - Track who made changes and when
✅ **Web UI** - Visual interface for version management

## Architecture

The versioning system uses the **Adapter Pattern** to support different storage backends:

```
┌─────────────────────┐
│  VersionManager     │  High-level API
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Adapter (Base)     │  Abstract interface
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐  ┌────────────────┐
│ File     │  │ ActiveRecord   │  Concrete adapters
│ Storage  │  │ (Rails)        │
└──────────┘  └────────────────┘
```

### Components

1. **VersionManager** - High-level service for version operations
2. **Adapter** - Abstract base for storage backends
3. **FileStorageAdapter** - JSON file-based storage (default)
4. **ActiveRecordAdapter** - Database storage for Rails apps
5. **Web UI** - Visual rule builder with version history

## Installation

### For Standalone / Sinatra Apps

No additional setup required! The gem uses file-based storage by default.

```ruby
require 'decision_agent'

manager = DecisionAgent::Versioning::VersionManager.new
# Versions are stored in ./versions/ directory
```

### For Rails Apps

1. **Run the generator** to install models and migrations:

```bash
rails generate decision_agent:install
```

This creates:
- `app/models/rule.rb`
- `app/models/rule_version.rb`
- `db/migrate/[timestamp]_create_decision_agent_tables.rb`

2. **Run migrations**:

```bash
rails db:migrate
```

3. **Use the models**:

```ruby
# The VersionManager will auto-detect ActiveRecord
manager = DecisionAgent::Versioning::VersionManager.new

# Or use models directly
rule = Rule.create!(
  rule_id: 'approval_001',
  ruleset: 'approval',
  description: 'Approval rules'
)

rule.create_version(
  content: { /* rule JSON */ },
  created_by: 'admin'
)
```

## Usage

### Basic Version Management

```ruby
require 'decision_agent'

manager = DecisionAgent::Versioning::VersionManager.new

# Save a new version
rule_content = {
  version: "1.0",
  ruleset: "approval",
  rules: [
    {
      id: "high_value",
      if: { field: "amount", op: "gt", value: 1000 },
      then: { decision: "approve", weight: 0.9, reason: "High value transaction" }
    }
  ]
}

version = manager.save_version(
  rule_id: "approval_001",
  rule_content: rule_content,
  created_by: "admin",
  changelog: "Added high value rule"
)
# => {
#   id: "approval_001_v1",
#   rule_id: "approval_001",
#   version_number: 1,
#   content: { ... },
#   created_by: "admin",
#   created_at: "2025-01-15T10:30:00Z",
#   changelog: "Added high value rule",
#   status: "active"
# }
```

### List Versions

```ruby
# Get all versions for a rule
versions = manager.get_versions(rule_id: "approval_001")

# Limit results
recent_versions = manager.get_versions(rule_id: "approval_001", limit: 5)
```

### Get Specific Version

```ruby
# By version ID
version = manager.get_version(version_id: "approval_001_v1")

# Get active version
active = manager.get_active_version(rule_id: "approval_001")
```

### Rollback to Previous Version

```ruby
# Rollback to a specific version
rolled_back = manager.rollback(
  version_id: "approval_001_v3",
  performed_by: "admin"
)

# This activates v3 and creates a new version documenting the rollback
```

### Compare Versions

```ruby
comparison = manager.compare(
  version_id_1: "approval_001_v1",
  version_id_2: "approval_001_v2"
)

# => {
#   version_1: { ... },
#   version_2: { ... },
#   differences: {
#     added: [...],
#     removed: [...],
#     changed: { field: { old: "value1", new: "value2" } }
#   }
# }
```

### Version History with Metadata

```ruby
history = manager.get_history(rule_id: "approval_001")

# => {
#   rule_id: "approval_001",
#   total_versions: 5,
#   active_version: { ... },
#   versions: [ ... ],
#   created_at: "2025-01-15T10:30:00Z",
#   updated_at: "2025-01-15T14:45:00Z"
# }
```

## Web UI

The Sinatra web server includes a visual interface for version management.

### Start the Server

```bash
# Command line
decision_agent web

# Or programmatically
DecisionAgent::Web::Server.start!(port: 4567)
```

Visit `http://localhost:4567` to access the rule builder with version features.

### Web UI Features

1. **Save Version** - Save current rules as a new version
   - Enter "Created By" name
   - Add changelog description
   - Auto-increments version number

2. **Version History** - View all versions in a table
   - Version number
   - Created by
   - Timestamp
   - Status (active/draft/archived)
   - Changelog

3. **Load Version** - Load any previous version into the editor

4. **Rollback** - Activate a previous version
   - Deactivates current active version
   - Creates audit trail

5. **Compare** - Side-by-side diff of two versions
   - Visual comparison
   - Change summary (added/removed/changed)

## API Reference

### VersionManager

#### `#save_version(rule_id:, rule_content:, created_by: 'system', changelog: nil)`

Save a new version of a rule.

**Parameters:**
- `rule_id` (String) - Unique identifier for the rule
- `rule_content` (Hash) - Rule definition
- `created_by` (String) - User creating the version (default: 'system')
- `changelog` (String) - Description of changes (auto-generated if nil)

**Returns:** Hash with version details

**Raises:**
- `ValidationError` if rule_content is invalid

---

#### `#get_versions(rule_id:, limit: nil)`

Get all versions for a rule.

**Parameters:**
- `rule_id` (String) - Rule identifier
- `limit` (Integer, nil) - Optional limit

**Returns:** Array of version hashes

---

#### `#get_version(version_id:)`

Get a specific version by ID.

**Parameters:**
- `version_id` (String) - Version identifier

**Returns:** Version hash or nil

---

#### `#get_active_version(rule_id:)`

Get the currently active version.

**Parameters:**
- `rule_id` (String) - Rule identifier

**Returns:** Active version hash or nil

---

#### `#rollback(version_id:, performed_by: 'system')`

Rollback to a previous version.

**Parameters:**
- `version_id` (String) - Version to activate
- `performed_by` (String) - User performing rollback

**Returns:** Activated version hash

**Note:** Creates a new version documenting the rollback

---

#### `#compare(version_id_1:, version_id_2:)`

Compare two versions.

**Parameters:**
- `version_id_1` (String) - First version ID
- `version_id_2` (String) - Second version ID

**Returns:** Comparison hash with differences

---

#### `#get_history(rule_id:)`

Get complete history with metadata.

**Parameters:**
- `rule_id` (String) - Rule identifier

**Returns:** History hash with stats and versions

## Storage Adapters

### FileStorageAdapter (Default)

Stores versions as JSON files in a directory structure.

```ruby
adapter = DecisionAgent::Versioning::FileStorageAdapter.new(
  storage_path: "./versions"  # default
)

manager = DecisionAgent::Versioning::VersionManager.new(adapter: adapter)
```

**Directory Structure:**
```
versions/
├── approval_001/
│   ├── 1.json
│   ├── 2.json
│   └── 3.json
└── content_moderation/
    ├── 1.json
    └── 2.json
```

**Pros:**
- No database required
- Simple setup
- Easy to backup
- Human-readable files

**Cons:**
- Not suitable for high concurrency
- Limited querying capabilities

### ActiveRecordAdapter (Rails)

Uses database storage via ActiveRecord.

```ruby
# Auto-detected when Rails is present
manager = DecisionAgent::Versioning::VersionManager.new
```

**Database Schema:**

```ruby
create_table :rules do |t|
  t.string :rule_id, null: false, index: { unique: true }
  t.string :ruleset, null: false
  t.text :description
  t.string :status, default: 'active'
  t.timestamps
end

create_table :rule_versions do |t|
  t.string :rule_id, null: false, index: true
  t.integer :version_number, null: false
  t.text :content, null: false
  t.string :created_by, null: false
  t.text :changelog
  t.string :status, null: false, default: 'draft'
  t.timestamps
end
```

**Pros:**
- Production-ready
- Supports concurrency
- Advanced querying
- Transactions

**Cons:**
- Requires database setup
- Rails dependency for ActiveRecord adapter

### Custom Adapters

Create custom adapters by inheriting from `DecisionAgent::Versioning::Adapter`:

```ruby
class RedisAdapter < DecisionAgent::Versioning::Adapter
  def create_version(rule_id:, content:, metadata: {})
    # Your implementation
  end

  def list_versions(rule_id:, limit: nil)
    # Your implementation
  end

  # ... implement other methods
end

manager = DecisionAgent::Versioning::VersionManager.new(
  adapter: RedisAdapter.new
)
```

## HTTP API Endpoints

When using the Sinatra web server:

### `POST /api/versions`

Create a new version.

```bash
curl -X POST http://localhost:4567/api/versions \
  -H "Content-Type: application/json" \
  -d '{
    "rule_id": "approval_001",
    "content": { "version": "1.0", "rules": [...] },
    "created_by": "admin",
    "changelog": "Initial version"
  }'
```

### `GET /api/rules/:rule_id/versions`

List versions for a rule.

```bash
curl http://localhost:4567/api/rules/approval_001/versions?limit=10
```

### `GET /api/rules/:rule_id/history`

Get version history with metadata.

```bash
curl http://localhost:4567/api/rules/approval_001/history
```

### `GET /api/versions/:version_id`

Get a specific version.

```bash
curl http://localhost:4567/api/versions/approval_001_v1
```

### `POST /api/versions/:version_id/activate`

Activate a version (rollback).

```bash
curl -X POST http://localhost:4567/api/versions/approval_001_v3/activate \
  -H "Content-Type: application/json" \
  -d '{ "performed_by": "admin" }'
```

### `GET /api/versions/:id1/compare/:id2`

Compare two versions.

```bash
curl http://localhost:4567/api/versions/approval_001_v1/compare/approval_001_v2
```

## Best Practices

1. **Use Meaningful Changelogs** - Document what changed and why
   ```ruby
   manager.save_version(
     rule_id: "approval_001",
     rule_content: content,
     changelog: "Increased approval threshold from $1000 to $5000 per compliance review"
   )
   ```

2. **Track Who Made Changes** - Always specify `created_by`
   ```ruby
   manager.save_version(
     rule_id: "approval_001",
     rule_content: content,
     created_by: current_user.email
   )
   ```

3. **Version Before Deployment** - Create versions before deploying to production

4. **Regular Backups** - For file storage, backup the `versions/` directory

5. **Test Rollbacks** - Verify rollback functionality in staging

6. **Use Status Field** - Leverage draft/active/archived statuses
   - `draft` - Work in progress
   - `active` - Currently in use
   - `archived` - Historical version

## Troubleshooting

### Versions Not Persisting

**File Storage:**
- Check directory permissions for `./versions/`
- Verify disk space

**ActiveRecord:**
- Run migrations: `rails db:migrate`
- Check database connectivity

### Auto-Detection Not Working

Explicitly specify an adapter:

```ruby
# Force file storage
adapter = DecisionAgent::Versioning::FileStorageAdapter.new
manager = DecisionAgent::Versioning::VersionManager.new(adapter: adapter)

# Force ActiveRecord (requires Rails + models)
adapter = DecisionAgent::Versioning::ActiveRecordAdapter.new
manager = DecisionAgent::Versioning::VersionManager.new(adapter: adapter)
```

## License

Part of DecisionAgent gem - MIT License
