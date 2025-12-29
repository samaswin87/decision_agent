# Web UI Rails Integration

The DecisionAgent Web UI can be easily mounted in your Rails application as a Rack endpoint.

## Quick Setup

### 1. Add to Gemfile

```ruby
gem 'decision_agent'
```

### 2. Mount in Routes

Add to `config/routes.rb`:

```ruby
require 'decision_agent/web/server'

Rails.application.routes.draw do
  # Mount DecisionAgent Web UI
  mount DecisionAgent::Web::Server, at: '/decision_agent'

  # Your other routes...
end
```

### 3. Access the UI

Start your Rails server and visit:
```
http://localhost:3000/decision_agent
```

## Advanced Configuration

### With Authentication

Protect the web UI with authentication:

```ruby
# config/routes.rb
require 'decision_agent/web/server'

Rails.application.routes.draw do
  authenticate :user, ->(user) { user.admin? } do
    mount DecisionAgent::Web::Server, at: '/decision_agent'
  end
end
```

Or using a constraint:

```ruby
# config/routes.rb
require 'decision_agent/web/server'

Rails.application.routes.draw do
  # Only allow admins to access
  constraints lambda { |request| request.env['warden'].user&.admin? } do
    mount DecisionAgent::Web::Server, at: '/decision_agent'
  end
end
```

### With HTTP Basic Auth

Add basic authentication:

```ruby
# config/initializers/decision_agent_web.rb
DecisionAgent::Web::Server.class_eval do
  use Rack::Auth::Basic do |username, password|
    username == ENV['DECISION_AGENT_USERNAME'] &&
    password == ENV['DECISION_AGENT_PASSWORD']
  end
end
```

### Custom Path

Mount at a different path:

```ruby
mount DecisionAgent::Web::Server, at: '/admin/rules'
# Access at: http://localhost:3000/admin/rules
```

## Rack App Integration (Non-Rails)

For Sinatra or other Rack applications:

### Sinatra

```ruby
# config.ru or app.rb
require 'sinatra'
require 'decision_agent/web/server'

# Mount as a sub-app
map '/decision_agent' do
  run DecisionAgent::Web::Server
end

map '/' do
  run YourSinatraApp
end
```

### config.ru

```ruby
require 'decision_agent/web/server'
require './your_app'

map '/decision_agent' do
  run DecisionAgent::Web::Server
end

map '/' do
  run YourApp
end
```

## Standalone Usage

Run as a standalone server (without mounting):

```bash
# From command line
decision_agent web

# Custom port
decision_agent web 8080
```

Or in your Ruby code:

```ruby
require 'decision_agent/web/server'

# Start on default port 4567
DecisionAgent::Web::Server.start!

# Custom port and host
DecisionAgent::Web::Server.start!(port: 8080, host: '0.0.0.0')
```

## Features

The Web UI provides:
- **Visual Rule Builder** - Create rules without writing JSON
- **Rule Validation** - Real-time validation as you build
- **Test Evaluation** - Test rules against sample contexts
- **Version Management** - View and manage rule versions
- **Example Templates** - Pre-built rule examples to get started

## Security Considerations

### Production Deployment

In production, always protect the web UI:

1. **Authentication** - Require user login
2. **Authorization** - Restrict to admin users only
3. **HTTPS** - Use SSL/TLS encryption
4. **Network** - Restrict access via firewall/VPN if possible

### Example Production Setup

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Restrict to admin users only
  authenticate :user, ->(user) { user.admin? } do
    mount DecisionAgent::Web::Server, at: '/decision_agent'
  end
end

# config/environments/production.rb
config.force_ssl = true  # Enforce HTTPS
```

## Troubleshooting

### UI Not Loading

1. **Check routes**: Run `rails routes | grep decision_agent`
2. **Verify mount path**: Ensure the path in `mount ... at:` matches your URL
3. **Check logs**: Look for errors in `log/development.log` or `log/production.log`

### Assets Not Found

If CSS/JS files aren't loading:

1. Ensure the gem is properly installed: `bundle install`
2. Check that public folder is included in gem files
3. Restart your Rails server

### CORS Issues

If you're accessing the API from a different domain:

```ruby
# config/initializers/decision_agent_web.rb
DecisionAgent::Web::Server.class_eval do
  set :allow_origin, 'https://your-frontend-domain.com'
end
```

## API Endpoints

The mounted UI exposes these API endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web UI home page |
| `/api/validate` | POST | Validate rules JSON |
| `/api/evaluate` | POST | Test rule evaluation |
| `/api/examples` | GET | Get example rules |
| `/api/versions` | POST | Create new version |
| `/api/rules/:id/versions` | GET | List versions |
| `/api/rules/:id/history` | GET | Get version history |
| `/api/versions/:id` | GET | Get specific version |
| `/api/versions/:id/activate` | POST | Rollback to version |
| `/api/versions/:id1/compare/:id2` | GET | Compare versions |
| `/health` | GET | Health check |

All API endpoints are automatically prefixed with your mount path (e.g., `/decision_agent/api/validate`).

## Next Steps

- [Web UI User Guide](WEB_UI.md) - Learn how to use the visual rule builder
- [API Contract](API_CONTRACT.md) - Full API documentation
- [Versioning System](VERSIONING.md) - Rule version control details
