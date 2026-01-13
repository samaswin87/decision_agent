# Web UI Integration Guide

The DecisionAgent Web UI can be easily mounted in any Rack-based Ruby web framework. This guide covers integration with Rails, Sinatra, Hanami, Padrino, Roda, Cuba, and generic Rack applications.

## Framework Quick Reference

| Framework | Integration Method | Complexity | Best For |
|-----------|-------------------|------------|----------|
| **Rails** | Mount in routes.rb | Easy | Full-stack applications |
| **Sinatra** | Mount or use middleware | Easy | Lightweight APIs |
| **Hanami** | Mount in routes | Medium | Modern full-stack apps |
| **Padrino** | Mount in app | Easy | Sinatra-based apps |
| **Roda** | Route plugin | Medium | Routing tree apps |
| **Cuba** | Mount in routes | Easy | Microservices |
| **Generic Rack** | config.ru | Easy | Custom applications |

## Rails Integration

Rails is a full-stack web framework. The DecisionAgent Web UI mounts seamlessly as a Rack application.

### Quick Setup

Add to Gemfile:

```ruby
gem 'decision_agent'
```

Mount in Routes

Add to `config/routes.rb`:

```ruby
require 'decision_agent/web/server'

Rails.application.routes.draw do
  # Mount DecisionAgent Web UI
  mount DecisionAgent::Web::Server, at: '/decision_agent'

  # Your other routes...
end
```

### Access the UI

Start your Rails server and visit:
```
http://localhost:3000/decision_agent
```

## Sinatra Integration

Sinatra is a lightweight DSL for quickly creating web applications in Ruby.

### Basic Setup

```ruby
require 'sinatra'
require 'decision_agent/web/server'

class MyApp < Sinatra::Base
  # Mount DecisionAgent Web UI at /decision_agent
  use DecisionAgent::Web::Server
  
  # Your routes
  get '/' do
    'Hello World'
  end
end
```

### Using Rack::URLMap

```ruby
require 'sinatra'
require 'decision_agent/web/server'

class MyApp < Sinatra::Base
  get '/' do
    'Hello World'
  end
end

# config.ru
run Rack::URLMap.new(
  '/' => MyApp,
  '/decision_agent' => DecisionAgent::Web::Server
)
```

### With Authentication

```ruby
require 'sinatra'
require 'decision_agent/web/server'

class MyApp < Sinatra::Base
  # HTTP Basic Auth for DecisionAgent paths
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    username == ENV['ADMIN_USER'] && password == ENV['ADMIN_PASS']
  end
  
  use DecisionAgent::Web::Server
  
  get '/' do
    'Hello World'
  end
end
```

### Modular Application

```ruby
# app.rb
require 'sinatra/base'
require 'decision_agent/web/server'

module MyCompany
  class App < Sinatra::Base
    use DecisionAgent::Web::Server
    
    get '/' do
      erb :index
    end
  end
end

# config.ru
require './app'
run MyCompany::App
```

See [examples/config.ru.example](../examples/config.ru.example) for more Sinatra deployment examples.

## Hanami Integration

Hanami is a modern full-stack Ruby web framework.

### Setup for Hanami 2.x

Add to `config/routes.rb`:

```ruby
# config/routes.rb
require 'decision_agent/web/server'

module MyApp
  class Routes < Hanami::Routes
    # Mount DecisionAgent Web UI
    mount DecisionAgent::Web::Server, at: '/decision_agent'
    
    # Your routes
    root to: 'home.index'
  end
end
```

### With Authentication

```ruby
# config/routes.rb
require 'decision_agent/web/server'

module MyApp
  class Routes < Hanami::Routes
    # Protect with custom middleware
    scope 'decision_agent' do
      use MyApp::Middleware::AdminAuth
      mount DecisionAgent::Web::Server, at: '/'
    end
    
    root to: 'home.index'
  end
end
```

### Hanami 1.x Integration

```ruby
# config/environment.rb
require 'decision_agent/web/server'

# apps/web/config/routes.rb
mount DecisionAgent::Web::Server, at: '/decision_agent'
```

## Padrino Integration

Padrino is a Ruby framework built on top of Sinatra.

### Basic Setup

```ruby
# app/app.rb
require 'decision_agent/web/server'

module MyApp
  class App < Padrino::Application
    # Mount DecisionAgent Web UI
    use DecisionAgent::Web::Server
    
    # Your routes
    get :index do
      render :index
    end
  end
end
```

### Using Padrino Mount

```ruby
# config/apps.rb
Padrino.mount('MyApp::App').to('/')
Padrino.mount('DecisionAgent::Web::Server').to('/decision_agent')
```

### With Authorization

```ruby
# app/app.rb
require 'decision_agent/web/server'

module MyApp
  class App < Padrino::Application
    before '/decision_agent/*' do
      halt 403 unless current_user&.admin?
    end
    
    use DecisionAgent::Web::Server
  end
end
```

## Roda Integration

Roda is a routing tree web framework for Ruby.

### Basic Setup

```ruby
# app.rb
require 'roda'
require 'decision_agent/web/server'

class App < Roda
  route do |r|
    # Mount DecisionAgent Web UI
    r.on 'decision_agent' do
      r.run DecisionAgent::Web::Server
    end
    
    # Your routes
    r.root do
      'Hello World'
    end
  end
end

# config.ru
run App.freeze.app
```

### With Authentication

```ruby
# app.rb
require 'roda'
require 'decision_agent/web/server'

class App < Roda
  plugin :sessions, secret: ENV['SESSION_SECRET']
  
  route do |r|
    r.on 'decision_agent' do
      # Authentication check
      r.halt(403) unless session[:admin]
      
      r.run DecisionAgent::Web::Server
    end
    
    r.root do
      'Hello World'
    end
  end
end
```

### Using Multi-Route Plugin

```ruby
require 'roda'
require 'decision_agent/web/server'

class App < Roda
  plugin :multi_route
  
  route do |r|
    r.on 'decision_agent' do
      r.run DecisionAgent::Web::Server
    end
    
    r.multi_route
  end
  
  route('home') do |r|
    r.root do
      'Hello World'
    end
  end
end
```

## Cuba Integration

Cuba is a microframework for web development.

### Basic Setup

```ruby
# app.rb
require 'cuba'
require 'decision_agent/web/server'

Cuba.define do
  # Mount DecisionAgent Web UI
  on 'decision_agent' do
    run DecisionAgent::Web::Server
  end
  
  # Your routes
  on root do
    res.write 'Hello World'
  end
end

# config.ru
run Cuba
```

### With Authentication

```ruby
require 'cuba'
require 'decision_agent/web/server'

Cuba.plugin Cuba::Session

Cuba.define do
  on 'decision_agent' do
    # Check admin session
    halt res.status = 403 unless session[:admin]
    
    run DecisionAgent::Web::Server
  end
  
  on root do
    res.write 'Hello World'
  end
end
```

### Modular Application

```ruby
# decision_agent_app.rb
require 'cuba'
require 'decision_agent/web/server'

class DecisionAgentApp < Cuba
  define do
    run DecisionAgent::Web::Server
  end
end

# main_app.rb
require 'cuba'
require_relative 'decision_agent_app'

Cuba.define do
  on 'decision_agent' do
    run DecisionAgentApp
  end
  
  on root do
    res.write 'Main App'
  end
end
```

## Generic Rack Application Integration

For any Rack-based application, you can mount DecisionAgent Web UI using a `config.ru` file.

### Basic config.ru

```ruby
require 'decision_agent/web/server'

# Option 1: Run DecisionAgent Web UI only
run DecisionAgent::Web::Server
```

### With Multiple Apps

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

### With Middleware

```ruby
require 'decision_agent/web/server'
require 'rack/auth/basic'

# Add authentication
use Rack::Auth::Basic, "DecisionAgent Admin" do |username, password|
  username == ENV['DECISION_AGENT_USERNAME'] &&
  password == ENV['DECISION_AGENT_PASSWORD']
end

run DecisionAgent::Web::Server
```

See [examples/config.ru.example](../examples/config.ru.example) for more deployment examples and [examples/03_rack_app.rb](../examples/03_rack_app.rb) for a complete Rack application example.

## Advanced Configuration for Rails

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

### Disabling Permissions in Development

For development environments, you can disable permission checks to simplify testing and development. **Note:** Authentication is still required; only permission checks are skipped.

**Option 1: Automatic (Development Environment)**

Permissions are automatically disabled when running in development mode:

```bash
# Development mode (permissions disabled automatically)
RACK_ENV=development
# or
RAILS_ENV=development
```

**Option 2: Explicit Environment Variable**

You can explicitly control permission checks using the `DISABLE_WEBUI_PERMISSIONS` environment variable:

```bash
# Disable permissions in any environment
DISABLE_WEBUI_PERMISSIONS=true

# Explicitly enable permissions (even in development)
DISABLE_WEBUI_PERMISSIONS=false RACK_ENV=development
```

**In Rails:**

Add to your `config/environments/development.rb`:

```ruby
# config/environments/development.rb
ENV['DISABLE_WEBUI_PERMISSIONS'] = 'true'
```

Or use an initializer:

```ruby
# config/initializers/decision_agent_web.rb
if Rails.env.development?
  ENV['DISABLE_WEBUI_PERMISSIONS'] = 'true'
end
```

**Security Notes:**
- Authentication is still required - only permission checks are skipped
- Production environments are safe by default (permissions enabled unless explicitly disabled)
- Use this feature only in development/testing environments

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
