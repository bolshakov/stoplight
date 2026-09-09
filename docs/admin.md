# Admin Panel: Dashboard & Control

Stoplight's Admin Panel is a built-in Sinatra dashboard for observing and controlling lights. It displays all active
lights, their current state, recent failures, and provides controls to lock/unlock lights manually.

## Basic Setup

### Rails Integration

Mount the Admin Panel in your Rails routes with basic authentication:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  Stoplight::Admin.use(Rack::Auth::Basic) do |username, password|
    username == ENV["STOPLIGHT_ADMIN_USERNAME"] &&
      password == ENV["STOPLIGHT_ADMIN_PASSWORD"]
  end

  mount Stoplight::Admin => "/stoplights"
end
```

Then set environment variables:

```bash
export STOPLIGHT_ADMIN_USERNAME=admin
export STOPLIGHT_ADMIN_PASSWORD=secret
```

Visit `http://localhost:3000/stoplights` to access the dashboard.

### Standalone Docker Setup

Run the Admin Panel as a separate service using the official Docker image:

```bash
docker run \
  -e REDIS_URL=redis://localhost:6379 \
  -e STOPLIGHT_ADMIN_USERNAME=admin \
  -e STOPLIGHT_ADMIN_PASSWORD=secret \
  -p 4567:4567 \
  bolshakov/stoplight-admin
```

The panel will be available at `http://localhost:4567`.

## Multi-System Configuration

When your application manages multiple isolated systems (multi-tenancy, service boundaries, etc.), the Admin Panel can
display and control all of them through a system switcher.

### Register Systems with Admin

```ruby
# config/initializers/stoplight.rb
require "stoplight"

Stoplight.configure do |config|
  config.data_store = Redis.new
end

# Create your systems
Payments = Stoplight.register_system("Payments", threshold: 3, cool_off_time: 30)
Analytics = Stoplight.register_system("Analytics", threshold: 5, cool_off_time: 60)

# Register them with Admin
Stoplight::Admin.configure do |config|
  config.add_system Payments
  config.add_system Analytics
end
```

When multiple systems are registered, the Admin Panel displays a system switcher in the top navigation bar. Clicking it
lets you view and control lights for each system independently.

### System Requirements

**Important:** Admin Panel requires all systems to use a **persistent data store** (Redis or Valkey). In-memory stores
are not supported because:

- Admin state persists across page refreshes
- Multi-instance deployments need shared state
- Data survives application restarts

If you try to register a system with an in-memory data store, Admin raises a `TypeError`:

```ruby
in_memory_system = Stoplight.register_system(
  "Ephemeral",
  data_store: Stoplight::DataStore::Memory.new
)

Stoplight::Admin.configure do |config|
  config.add_system in_memory_system # raises TypeError
end
```

### Default System Fallback

If you don't explicitly register any systems, Admin automatically uses the default system:

```ruby
Stoplight.configure do |config|
  config.data_store = Redis.new
end

# Don't call Stoplight::Admin.configure, and Admin uses the default system
mount Stoplight::Admin => "/stoplights"
```

The system switcher is hidden when only one system is active.

## System Switcher UI

When multiple systems are configured, a dropdown menu appears in the top navigation:

- Shows all registered system names
- Current system is highlighted in blue
- Click any system name to view its lights
- All lights, stats, and controls are scoped to the selected system
- Lock/unlock actions affect only the current system's lights

## Read-Only Mode

Deploy Admin as read-only across all systems by disabling write controls:

```ruby
Stoplight::Admin.configure do |config|
  config.add_system Payments
  config.add_system Analytics
  config.read_only = true
end

mount Stoplight::Admin => "/stoplights"
```

In read-only mode:

- All lights and stats remain visible
- Lock, unlock, and remove buttons are hidden and disabled
- Requests to endpoints that would modify state return 403
- A "Read-only" label appears in the top navigation

This is useful for:

- **Observability dashboards**: Developers can see state without risking accidental changes
- **Multi-team environments**: Shared visibility without cross-team write access
- **Compliance**: Audit-trail-friendly observation-only deployments

**Note:** Read-only is not access control — anyone who can reach the panel sees all light names and recent failures.
Always keep the Admin Panel behind authentication.

### Standalone Docker Read-Only Mode

```bash
docker run \
  -e REDIS_URL=redis://localhost:6379 \
  -e STOPLIGHT_ADMIN_READ_ONLY=true \
  -p 4567:4567 \
  bolshakov/stoplight-admin
```

## Dashboard Features

### Lights List

For the current system, displays:

- **Light Name**: Circuit breaker identifier
- **State**: Green (normal), Yellow (recovering), or Red (open)
- **Recent Failures**: List of the most recent errors with timestamps
- **Actions**: Lock, unlock, and remove controls (if not read-only)

### Stats Panel

Shows aggregate metrics for the current system:

- Total lights
- Lights by color (green, yellow, red)
- Quick actions to lock/unlock all lights at once

### Lock/Unlock Controls

#### Lock Green

Force a light to remain green (allow all traffic), even if it would normally trip. Useful for:

- Emergency overrides during critical operations
- Gradual rollouts where you want to manually control traffic
- Testing scenarios

#### Lock Red

Force a light to remain red (block all traffic) without waiting for the cool-off period. Useful for:

- Planned maintenance windows
- Graceful degradation when a dependency is known to be down
- Reducing cascading failures

#### Unlock

Return a light to automatic state transitions. Removes manual overrides and lets Stoplight's state machine control the
light normally.

#### Lock All / Unlock All

Bulk operations in the stats panel:

- **Lock All Green**: Unlock all red and yellow lights at once
- **Lock All Red**: Requires per-light confirmation to prevent accidents

## API Endpoints

The Admin Panel exposes JSON endpoints for programmatic access:

### Get Stats

```
GET /stats
```

Returns aggregate stats and lights for the default system (for external monitors, backwards compatibility).

```bash
curl http://localhost:4567/stats | jq
```

Response:

```json
{
  "stats": {
    "green": 5,
    "yellow": 1,
    "red": 2
  },
  "lights": [
    {
      "name": "stripe",
      "color": "red",
      "failures": [
        {
          "message": "Connection timeout",
          "time": "2025-09-02T12:34:56Z"
        }
      ]
    }
  ]
}
```

### Get System Lights

```
GET /systems/:system_id/lights.json
```

Returns lights and stats for a specific system:

```bash
curl http://localhost:4567/systems/abc123/lights.json | jq
```

## Assets & Performance

The Admin Panel includes:

- Tailwind CSS for styling (served from inline styles)
- Turbo for fast navigation (navigation state preserved)
- Flowbite UI components for accessibility
- Static assets cached with 1-year expiry (asset filenames include content hash)

All assets are bundled — no external CDN dependencies.

## Content Security Policy & Nonces

If your application uses Content Security Policy (CSP), you can inject a nonce for inline scripts:

```ruby
Stoplight::Admin.configure do |config|
  config.nonce = ->(request) do
    request.env["CSP_NONCE"] # Provided by your CSP middleware
  end
end
```

The nonce is injected into all inline `<script>` tags in the Admin Panel.
