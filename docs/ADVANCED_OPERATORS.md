# Advanced Rule DSL Operators

This document describes the advanced operators available in the Decision Agent Rule DSL. These operators extend the basic comparison operators (`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `present`, `blank`) with specialized functionality for strings, numbers, dates, collections, and geospatial data.

## Table of Contents

- [String Operators](#string-operators)
- [Numeric Operators](#numeric-operators)
- [Date/Time Operators](#datetime-operators)
- [Collection Operators](#collection-operators)
- [Geospatial Operators](#geospatial-operators)
- [Examples](#examples)

---

## String Operators

### `contains`

Checks if a string contains a substring (case-sensitive).

**Syntax:**
```json
{
  "field": "message",
  "op": "contains",
  "value": "error"
}
```

**Example:**
```json
{
  "version": "1.0",
  "ruleset": "error_detection",
  "rules": [
    {
      "id": "error_alert",
      "if": {
        "field": "log_message",
        "op": "contains",
        "value": "ERROR"
      },
      "then": {
        "decision": "send_alert",
        "weight": 0.9,
        "reason": "Error detected in log message"
      }
    }
  ]
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings
- Returns `false` if field is not a string

---

### `starts_with`

Checks if a string starts with a specified prefix (case-sensitive).

**Syntax:**
```json
{
  "field": "error_code",
  "op": "starts_with",
  "value": "ERR"
}
```

**Example:**
```json
{
  "field": "transaction_id",
  "op": "starts_with",
  "value": "TXN-"
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings

---

### `ends_with`

Checks if a string ends with a specified suffix (case-sensitive).

**Syntax:**
```json
{
  "field": "filename",
  "op": "ends_with",
  "value": ".pdf"
}
```

**Example:**
```json
{
  "id": "pdf_processor",
  "if": {
    "field": "document.filename",
    "op": "ends_with",
    "value": ".pdf"
  },
  "then": {
    "decision": "route_to_pdf_processor",
    "weight": 1.0
  }
}
```

**Behavior:**
- Case-sensitive matching
- Both field and value must be strings

---

### `matches`

Matches a string against a regular expression pattern.

**Syntax:**
```json
{
  "field": "email",
  "op": "matches",
  "value": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}
```

**Example:**
```json
{
  "id": "validate_email",
  "if": {
    "field": "user.email",
    "op": "matches",
    "value": "^[a-z0-9._%+-]+@company\\.com$"
  },
  "then": {
    "decision": "employee_email",
    "weight": 1.0,
    "reason": "Email is from company domain"
  }
}
```

**Behavior:**
- Value can be a regex string or Regexp object
- Invalid regex patterns return `false` (fail-safe)
- Field must be a string

**Common Patterns:**
- Email: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$`
- Phone (US): `^\\(\\d{3}\\)\\s?\\d{3}-\\d{4}$`
- UUID: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- IP Address: `^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$`

---

## Numeric Operators

### `between`

Checks if a numeric value is between a minimum and maximum value (inclusive).

**Syntax (Array Format):**
```json
{
  "field": "age",
  "op": "between",
  "value": [18, 65]
}
```

**Syntax (Hash Format):**
```json
{
  "field": "score",
  "op": "between",
  "value": { "min": 0, "max": 100 }
}
```

**Example:**
```json
{
  "id": "age_verification",
  "if": {
    "field": "applicant.age",
    "op": "between",
    "value": [21, 70]
  },
  "then": {
    "decision": "eligible",
    "weight": 0.9,
    "reason": "Applicant age is within acceptable range"
  }
}
```

**Behavior:**
- Boundary values are included (closed interval)
- Field must be numeric
- Supports both integer and floating-point numbers

---

### `modulo`

Checks if a value modulo a divisor equals a specified remainder.

**Syntax (Array Format):**
```json
{
  "field": "order_id",
  "op": "modulo",
  "value": [2, 0]
}
```

**Syntax (Hash Format):**
```json
{
  "field": "customer_id",
  "op": "modulo",
  "value": { "divisor": 10, "remainder": 5 }
}
```

**Example - Even Numbers:**
```json
{
  "id": "even_id_routing",
  "if": {
    "field": "user_id",
    "op": "modulo",
    "value": [2, 0]
  },
  "then": {
    "decision": "route_to_server_a",
    "weight": 1.0,
    "reason": "Route even user IDs to server A"
  }
}
```

**Example - A/B Testing:**
```json
{
  "id": "ab_test_variant_b",
  "if": {
    "field": "session_id",
    "op": "modulo",
    "value": { "divisor": 3, "remainder": 1 }
  },
  "then": {
    "decision": "show_variant_b",
    "weight": 1.0
  }
}
```

**Use Cases:**
- A/B testing distribution
- Load balancing
- Sharding logic
- Identifying patterns (even/odd numbers)

---

## Date/Time Operators

All date/time operators accept dates in multiple formats:
- ISO 8601 strings: `"2025-12-31"` or `"2025-12-31T23:59:59Z"`
- Ruby Time objects
- Ruby Date objects
- Ruby DateTime objects

### `before_date`

Checks if a date is before a specified date.

**Syntax:**
```json
{
  "field": "expires_at",
  "op": "before_date",
  "value": "2026-01-01"
}
```

**Example:**
```json
{
  "id": "check_expiration",
  "if": {
    "field": "license.expires_at",
    "op": "before_date",
    "value": "2025-12-31"
  },
  "then": {
    "decision": "license_valid",
    "weight": 0.8,
    "reason": "License has not expired"
  }
}
```

---

### `after_date`

Checks if a date is after a specified date.

**Syntax:**
```json
{
  "field": "created_at",
  "op": "after_date",
  "value": "2024-01-01"
}
```

**Example:**
```json
{
  "id": "recent_account",
  "if": {
    "field": "account.created_at",
    "op": "after_date",
    "value": "2024-06-01"
  },
  "then": {
    "decision": "new_user_promotion",
    "weight": 0.9,
    "reason": "Account created recently"
  }
}
```

---

### `within_days`

Checks if a date is within N days from the current time (past or future).

**Syntax:**
```json
{
  "field": "event_date",
  "op": "within_days",
  "value": 7
}
```

**Example:**
```json
{
  "id": "upcoming_event_reminder",
  "if": {
    "field": "appointment.scheduled_at",
    "op": "within_days",
    "value": 3
  },
  "then": {
    "decision": "send_reminder",
    "weight": 1.0,
    "reason": "Appointment is within 3 days"
  }
}
```

**Behavior:**
- Calculates absolute difference (works for both past and future dates)
- Value is the number of days
- Uses current time as reference point

---

### `day_of_week`

Checks if a date falls on a specified day of the week.

**Syntax (String Format):**
```json
{
  "field": "delivery_date",
  "op": "day_of_week",
  "value": "monday"
}
```

**Syntax (Numeric Format):**
```json
{
  "field": "delivery_date",
  "op": "day_of_week",
  "value": 1
}
```

**Example:**
```json
{
  "id": "weekend_pricing",
  "if": {
    "any": [
      { "field": "booking_date", "op": "day_of_week", "value": "saturday" },
      { "field": "booking_date", "op": "day_of_week", "value": "sunday" }
    ]
  },
  "then": {
    "decision": "apply_weekend_discount",
    "weight": 1.0,
    "reason": "Weekend booking discount"
  }
}
```

**Supported Values:**
- **Strings:** `"sunday"`, `"monday"`, `"tuesday"`, `"wednesday"`, `"thursday"`, `"friday"`, `"saturday"`
- **Abbreviations:** `"sun"`, `"mon"`, `"tue"`, `"wed"`, `"thu"`, `"fri"`, `"sat"`
- **Numbers:** `0` (Sunday) through `6` (Saturday)

---

## Collection Operators

### `contains_all`

Checks if an array contains all of the specified elements.

**Syntax:**
```json
{
  "field": "permissions",
  "op": "contains_all",
  "value": ["read", "write"]
}
```

**Example:**
```json
{
  "id": "admin_access",
  "if": {
    "field": "user.permissions",
    "op": "contains_all",
    "value": ["read", "write", "delete"]
  },
  "then": {
    "decision": "grant_admin_access",
    "weight": 1.0,
    "reason": "User has all required permissions"
  }
}
```

**Behavior:**
- Both field and value must be arrays
- Order doesn't matter
- Field can contain additional elements

---

### `contains_any`

Checks if an array contains any of the specified elements.

**Syntax:**
```json
{
  "field": "tags",
  "op": "contains_any",
  "value": ["urgent", "critical", "emergency"]
}
```

**Example:**
```json
{
  "id": "priority_escalation",
  "if": {
    "field": "ticket.tags",
    "op": "contains_any",
    "value": ["urgent", "critical"]
  },
  "then": {
    "decision": "escalate_to_manager",
    "weight": 0.95,
    "reason": "Ticket has priority tag"
  }
}
```

**Behavior:**
- Both field and value must be arrays
- Returns `true` if at least one element matches

---

### `intersects`

Checks if two arrays have any common elements (set intersection).

**Syntax:**
```json
{
  "field": "user_roles",
  "op": "intersects",
  "value": ["admin", "moderator", "super_user"]
}
```

**Example:**
```json
{
  "id": "elevated_role_check",
  "if": {
    "field": "account.roles",
    "op": "intersects",
    "value": ["admin", "moderator"]
  },
  "then": {
    "decision": "allow_moderation_features",
    "weight": 1.0
  }
}
```

**Behavior:**
- Equivalent to `contains_any` but semantically indicates set comparison
- Returns `true` if intersection is non-empty

---

### `subset_of`

Checks if an array is a subset of another array (all elements are contained).

**Syntax:**
```json
{
  "field": "selected_options",
  "op": "subset_of",
  "value": ["option_a", "option_b", "option_c", "option_d"]
}
```

**Example:**
```json
{
  "id": "validate_selection",
  "if": {
    "field": "form.selected_features",
    "op": "subset_of",
    "value": ["feature_a", "feature_b", "feature_c"]
  },
  "then": {
    "decision": "valid_selection",
    "weight": 1.0,
    "reason": "All selected features are valid options"
  }
}
```

**Behavior:**
- Returns `true` if all elements in the field array exist in the value array
- Empty array is a subset of any array

---

## Geospatial Operators

### `within_radius`

Checks if a geographic point is within a specified radius of a center point.

**Syntax:**
```json
{
  "field": "location",
  "op": "within_radius",
  "value": {
    "center": { "lat": 40.7128, "lon": -74.0060 },
    "radius": 10
  }
}
```

**Coordinate Formats:**

**Hash Format:**
```json
{ "lat": 40.7128, "lon": -74.0060 }
{ "latitude": 40.7128, "longitude": -74.0060 }
{ "lat": 40.7128, "lng": -74.0060 }
```

**Array Format:**
```json
[40.7128, -74.0060]  // [latitude, longitude]
```

**Example:**
```json
{
  "id": "local_delivery",
  "if": {
    "field": "delivery.address.coordinates",
    "op": "within_radius",
    "value": {
      "center": { "lat": 37.7749, "lon": -122.4194 },
      "radius": 25
    }
  },
  "then": {
    "decision": "offer_same_day_delivery",
    "weight": 0.9,
    "reason": "Within 25km of distribution center"
  }
}
```

**Behavior:**
- Distance calculated using Haversine formula
- Radius is in kilometers
- Returns `false` if coordinates are invalid or missing

**Use Cases:**
- Delivery zone validation
- Store locator
- Geofencing
- Proximity-based routing

---

### `in_polygon`

Checks if a geographic point is inside a polygon using the ray casting algorithm.

**Syntax:**
```json
{
  "field": "location",
  "op": "in_polygon",
  "value": [
    { "lat": 40.0, "lon": -74.0 },
    { "lat": 41.0, "lon": -74.0 },
    { "lat": 41.0, "lon": -73.0 },
    { "lat": 40.0, "lon": -73.0 }
  ]
}
```

**Example - Service Area:**
```json
{
  "id": "service_area_check",
  "if": {
    "field": "customer.location",
    "op": "in_polygon",
    "value": [
      { "lat": 40.5, "lon": -74.5 },
      { "lat": 41.5, "lon": -74.5 },
      { "lat": 41.5, "lon": -73.0 },
      { "lat": 40.5, "lon": -73.0 }
    ]
  },
  "then": {
    "decision": "within_service_area",
    "weight": 1.0,
    "reason": "Customer is within our service area"
  }
}
```

**Example - Complex Boundary:**
```json
{
  "field": "store.location",
  "op": "in_polygon",
  "value": [
    [37.7749, -122.4194],
    [37.7849, -122.4094],
    [37.7949, -122.4194],
    [37.7849, -122.4294]
  ]
}
```

**Behavior:**
- Polygon must have at least 3 vertices
- Works with both hash and array coordinate formats
- Polygon is automatically closed (last point connects to first)
- Uses ray casting algorithm for point-in-polygon test

**Use Cases:**
- Service area boundaries
- Zoning validation
- Regulatory compliance zones
- Custom geographic regions

---

## Examples

### Complex Multi-Operator Rule

```json
{
  "version": "1.0",
  "ruleset": "fraud_detection",
  "rules": [
    {
      "id": "high_risk_transaction",
      "if": {
        "all": [
          {
            "field": "transaction.amount",
            "op": "between",
            "value": [1000, 10000]
          },
          {
            "field": "user.email",
            "op": "matches",
            "value": "^[a-z0-9._-]+@(gmail|yahoo|hotmail)\\.(com|net)$"
          },
          {
            "field": "user.account_age_days",
            "op": "lt",
            "value": 30
          },
          {
            "any": [
              {
                "field": "transaction.location",
                "op": "within_radius",
                "value": {
                  "center": { "lat": 40.7128, "lon": -74.0060 },
                  "radius": 100
                }
              },
              {
                "field": "user.risk_flags",
                "op": "contains_any",
                "value": ["vpn", "proxy", "tor"]
              }
            ]
          }
        ]
      },
      "then": {
        "decision": "require_additional_verification",
        "weight": 0.95,
        "reason": "High-risk transaction pattern detected"
      }
    }
  ]
}
```

### Email Domain Validation

```json
{
  "id": "corporate_email",
  "if": {
    "any": [
      { "field": "email", "op": "ends_with", "value": "@company.com" },
      { "field": "email", "op": "ends_with", "value": "@subsidiary.com" },
      { "field": "email", "op": "matches", "value": "^[a-z.]+@partner\\.(com|net)$" }
    ]
  },
  "then": {
    "decision": "grant_internal_access",
    "weight": 1.0
  }
}
```

### Scheduled Maintenance Window

```json
{
  "id": "maintenance_window",
  "if": {
    "all": [
      {
        "any": [
          { "field": "scheduled_time", "op": "day_of_week", "value": "saturday" },
          { "field": "scheduled_time", "op": "day_of_week", "value": "sunday" }
        ]
      },
      {
        "field": "scheduled_time",
        "op": "within_days",
        "value": 7
      }
    ]
  },
  "then": {
    "decision": "approve_maintenance",
    "weight": 0.9,
    "reason": "Scheduled during weekend maintenance window"
  }
}
```

### Delivery Zone Routing

```json
{
  "version": "1.0",
  "ruleset": "delivery_routing",
  "rules": [
    {
      "id": "zone_a_local",
      "if": {
        "field": "delivery_address.coordinates",
        "op": "in_polygon",
        "value": [
          { "lat": 40.7, "lon": -74.1 },
          { "lat": 40.8, "lon": -74.1 },
          { "lat": 40.8, "lon": -73.9 },
          { "lat": 40.7, "lon": -73.9 }
        ]
      },
      "then": {
        "decision": "route_to_zone_a",
        "weight": 1.0,
        "reason": "Address is in Zone A delivery polygon"
      }
    },
    {
      "id": "zone_b_radius",
      "if": {
        "field": "delivery_address.coordinates",
        "op": "within_radius",
        "value": {
          "center": { "lat": 40.75, "lon": -73.95 },
          "radius": 5
        }
      },
      "then": {
        "decision": "route_to_zone_b",
        "weight": 0.9,
        "reason": "Within 5km of Zone B distribution center"
      }
    }
  ]
}
```

### Permission-Based Access Control

```json
{
  "id": "feature_access",
  "if": {
    "all": [
      {
        "field": "user.permissions",
        "op": "contains_all",
        "value": ["feature_a_read", "feature_a_write"]
      },
      {
        "field": "user.roles",
        "op": "intersects",
        "value": ["power_user", "admin", "developer"]
      },
      {
        "field": "user.subscription_tier",
        "op": "in",
        "value": ["premium", "enterprise"]
      }
    ]
  },
  "then": {
    "decision": "grant_feature_a_access",
    "weight": 1.0,
    "reason": "User has required permissions and role"
  }
}
```

---

## Best Practices

### Performance Considerations

1. **String Operations**: `contains`, `starts_with`, and `ends_with` are faster than `matches`
2. **Geospatial**: Prefer `within_radius` for circular areas, `in_polygon` for irregular shapes
3. **Collections**: Use `contains_any` instead of multiple `eq` conditions in an `any` block

### Error Handling

All operators are designed to fail safely:
- Invalid regex patterns return `false`
- Type mismatches return `false`
- Missing or nil values return `false`
- Malformed coordinates return `false`

### Validation

The schema validator ensures:
- All operators are recognized before evaluation
- Required fields are present
- Value types are appropriate for the operator

---

## Migration from Basic Operators

### Before (Multiple Rules):
```json
{
  "any": [
    { "field": "status", "op": "eq", "value": "urgent" },
    { "field": "status", "op": "eq", "value": "critical" },
    { "field": "status", "op": "eq", "value": "emergency" }
  ]
}
```

### After (Single Rule):
```json
{
  "field": "status",
  "op": "in",
  "value": ["urgent", "critical", "emergency"]
}
```

### Or Even Better (with tags array):
```json
{
  "field": "tags",
  "op": "contains_any",
  "value": ["urgent", "critical", "emergency"]
}
```

---

## Web UI Support

All advanced operators are fully supported in the DecisionAgent Web UI:

- **Visual Builder** - All operators available in dropdown menus, organized by category
- **Smart Placeholders** - Context-aware placeholders guide you on the expected value format
- **Helpful Hints** - Hover over value fields to see format examples
- **Example Rules** - Load example rules showcasing the new operators

Launch the Web UI:
```bash
decision_agent web
```

Or mount in your Rails app:
```ruby
mount DecisionAgent::Web::Server, at: '/decision_agent'
```

## See Also

- [API Contract](API_CONTRACT.md) - Core API documentation
- [Thread Safety](THREAD_SAFETY.md) - Concurrency considerations
- [Performance](PERFORMANCE_AND_THREAD_SAFETY.md) - Performance optimization
- [Web UI](WEB_UI.md) - Visual rule builder documentation
