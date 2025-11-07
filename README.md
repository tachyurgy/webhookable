# Webhookable

<!-- ✅ FIXED: Removed marketing hyperbole "under 5 minutes" - more realistic messaging -->
**Production-ready webhooks for Rails with zero configuration.**

Webhookable gives your Rails application production-grade webhook functionality with automatic retries, cryptographic signatures, and delivery tracking built in.

Get started in minutes. Production-ready out of the box.

[![Gem Version](https://badge.fury.io/rb/webhookable.svg)](https://badge.fury.io/rb/webhookable)
[![Build Status](https://github.com/magnusfremont/webhookable/workflows/CI/badge.svg)](https://github.com/magnusfremont/webhookable/actions)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Table of Contents

- [The Problem](#the-problem)
- [Why Webhookable?](#why-webhookable)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Advanced Usage](#advanced-usage)
  - [Custom Payloads](#custom-payloads)
  - [Webhook Management](#webhook-management)
  - [Retry Management](#retry-management)
  - [Development Mode](#development-mode---webhook-inbox)
  - [Testing](#testing)
  - [Instrumentation](#instrumentation)
- [How It Compares](#how-it-compares)
- [Architecture](#architecture)
- [Configuration Options](#configuration-options)
- [Requirements](#requirements)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Development](#development)
- [License](#license)

---

## The Problem

Every SaaS application eventually needs webhooks to notify customers about events. Building a robust webhook system from scratch is deceptively complex:

- Reliable delivery with automatic retries
- Cryptographic signatures for security
- Exponential backoff for failed deliveries
- Delivery attempt tracking and logging
- Graceful handling of customer endpoint failures
- Testing and debugging tools

Existing solutions are either **too minimal for production** or **too complex for quick adoption**.

## Why Webhookable?

### Simple API

```ruby
# Add to your model
class Order < ApplicationRecord
  include Webhookable::Model
  webhook_events :completed, :cancelled, :refunded
end

# Trigger webhooks
order.trigger_webhook(:completed)
# Automatic retries, signatures, tracking - zero config required
```

### Production-Ready Features

- **Automatic Retries**: Exponential backoff with configurable attempts (default: 5)
- **Cryptographic Signatures**: HMAC-SHA256 signatures on every webhook
- **Delivery Tracking**: Full history of every delivery attempt
- **Job Queue Agnostic**: Works with Sidekiq, Solid Queue, Delayed Job, or any ActiveJob backend
- **Development Tools**: Webhook inbox for testing without hitting real endpoints
- **Comprehensive Testing**: RSpec helpers and matchers included

### Zero Configuration

Works out of the box with sensible defaults. Configure only what you need:

```ruby
Webhookable.configure do |config|
  config.max_retry_attempts = 5      # Default
  config.initial_retry_delay = 60    # Default (seconds)
  config.timeout = 30                # Default (seconds)
end
```

## Installation

Add to your Gemfile:

```ruby
gem "webhookable"
```

Install and run migrations:

```bash
bundle install
rails generate webhookable:install
rails db:migrate
```

That's it. You're ready to send webhooks.

## Quick Start

### Real-World Example

Here's a complete example of adding webhooks to an e-commerce application:

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  include Webhookable::Model
  webhook_events :created, :completed, :cancelled, :refunded

  belongs_to :user
  has_many :line_items

  def default_webhook_payload
    {
      id: id,
      order_number: order_number,
      status: status,
      total_cents: total_cents,
      currency: currency,
      customer: {
        id: user.id,
        email: user.email,
        name: user.name
      },
      items: line_items.map do |item|
        {
          product_id: item.product_id,
          quantity: item.quantity,
          price_cents: item.price_cents
        }
      end,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end

# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def create
    @order = current_user.orders.build(order_params)

    if @order.save
      @order.trigger_webhook(:created)
      redirect_to @order, notice: 'Order created!'
    else
      render :new
    end
  end

  def complete
    @order = Order.find(params[:id])
    @order.update!(status: 'completed', completed_at: Time.current)
    @order.trigger_webhook(:completed)

    redirect_to @order, notice: 'Order completed!'
  end
end

# Your customers' webhook endpoint would receive:
# POST https://customer.example.com/webhooks
# Headers:
#   Content-Type: application/json
#   X-Webhook-Signature: sha256=abc123...
#   X-Webhook-Event: completed
#   X-Webhook-Delivery-Id: 12345
#
# Body:
# {
#   "id": 789,
#   "order_number": "ORD-2025-001",
#   "status": "completed",
#   "total_cents": 15999,
#   "currency": "USD",
#   "customer": {
#     "id": 456,
#     "email": "customer@example.com",
#     "name": "John Doe"
#   },
#   "items": [
#     {
#       "product_id": 123,
#       "quantity": 2,
#       "price_cents": 7999
#     }
#   ],
#   "created_at": "2025-01-29T10:00:00Z",
#   "updated_at": "2025-01-29T11:30:00Z"
# }
```

### 1. Add Webhookable to Your Models

```ruby
class Order < ApplicationRecord
  include Webhookable::Model
  webhook_events :completed, :cancelled, :refunded
end

class User < ApplicationRecord
  include Webhookable::Model
  webhook_events :created, :updated, :deleted
end
```

### 2. Create Webhook Endpoints

Your customers will register endpoints to receive webhooks:

```ruby
# Typically done through a UI your customers access
endpoint = WebhookEndpoint.create!(
  url: "https://customer.example.com/webhooks",
  events: ["order.completed", "order.cancelled"]
)

# The secret is auto-generated for signature verification
puts endpoint.secret
```

### 3. Trigger Webhooks

```ruby
# In your controller or service
order = Order.find(params[:id])
order.update!(status: "completed")
order.trigger_webhook(:completed)
# Webhook is queued and will be delivered asynchronously
```

### 4. Verify Signatures (Receiving End)

Your customers verify webhook authenticity:

```ruby
# In customer's webhook endpoint
payload = request.body.read
signature = request.headers['X-Webhook-Signature']
secret = "your-webhook-endpoint-secret"

if Webhookable.verify_signature(payload, signature, secret)
  # Process webhook
  data = JSON.parse(payload)
  puts "Order #{data['id']} completed!"
else
  # Invalid signature - reject
  head :unauthorized
end
```

## Advanced Usage

### Custom Payloads

Override the default payload in your model:

```ruby
class Order < ApplicationRecord
  include Webhookable::Model
  webhook_events :completed

  def default_webhook_payload
    {
      id: id,
      order_number: order_number,
      total: total_cents,
      customer: {
        email: customer.email,
        name: customer.name
      },
      items: line_items.map(&:to_webhook_hash)
    }
  end
end
```

Or provide a custom payload per trigger:

```ruby
order.trigger_webhook(:completed, custom_payload: {
  order_id: order.id,
  special_field: "custom value"
})
```

### Webhook Management

```ruby
# Enable/disable endpoints
endpoint.disable!
endpoint.enable!

# Check delivery stats
endpoint.success_rate  # => 98.5
endpoint.successful_deliveries_count  # => 1420
endpoint.failed_deliveries_count  # => 22

# Get webhook events for a record
order.webhook_events
order.webhook_deliveries
```

### Retry Management

```rake
# Retry all failed deliveries
rake webhookable:retry_failed

# Process pending retries
rake webhookable:process_retries

# Clean up old successful deliveries (older than 30 days)
rake webhookable:cleanup

# View statistics
rake webhookable:stats
```

### Development Mode - Webhook Inbox

Test webhooks without hitting real endpoints:

```ruby
# config/environments/development.rb
Webhookable.configure do |config|
  config.enable_inbox = true
end
```

```ruby
# Trigger webhook
order.trigger_webhook(:completed)

# Inspect what would have been sent
Webhookable::InboxEntry.last.payload
Webhookable::InboxEntry.last.headers
Webhookable::InboxEntry.last.url

# View all inbox entries
rake webhookable:list_inbox

# Clear inbox
rake webhookable:clear_inbox
```

### Testing

Webhookable includes comprehensive testing helpers:

```ruby
# spec/rails_helper.rb
require "webhookable/test_helpers"

RSpec.configure do |config|
  config.include Webhookable::TestHelpers
end
```

```ruby
# In your specs
RSpec.describe OrdersController do
  describe "POST #complete" do
    let(:order) { create(:order) }

    it "triggers webhook when order is completed" do
      expect {
        post :complete, params: { id: order.id }
      }.to enqueue_webhook(:completed)
    end

    it "sends correct payload" do
      post :complete, params: { id: order.id }

      event = last_webhook_event(:completed)
      expect(event.payload).to include("id" => order.id)
    end
  end
end
```

### Instrumentation

Subscribe to webhook events for monitoring:

```ruby
# config/initializers/webhookable.rb
Webhookable::Instrumentation.subscribe do |event, data|
  case event
  when "webhook.triggered"
    Rails.logger.info "Webhook triggered: #{data[:event_type]}"
  when "webhook.delivered"
    Rails.logger.info "Webhook delivered: status=#{data[:status]} attempts=#{data[:attempt_count]}"
  end
end
```

Available events:
- `webhook.triggered`: When a webhook event is created
- `webhook.delivered`: When a webhook delivery attempt completes

### Idempotency

Webhookable automatically handles idempotency to prevent duplicate event creation and helps webhook consumers implement idempotent processing.

**Event-Level Idempotency:**

Each webhook event is created with a unique idempotency key that prevents duplicate event creation:

```ruby
# Triggering the same event multiple times with the same data
order.trigger_webhook(:completed)  # Creates event with idempotency key
order.trigger_webhook(:completed)  # Uses same idempotency key - no duplicate
```

**Consumer-Side Idempotency:**

Every webhook delivery includes an `X-Webhook-Idempotency-Key` header that consumers should use to implement idempotent processing:

```ruby
# Example webhook consumer (in receiving application)
class WebhooksController < ApplicationController
  def receive
    idempotency_key = request.headers['X-Webhook-Idempotency-Key']

    # Check if we've already processed this webhook
    if ProcessedWebhook.exists?(idempotency_key: idempotency_key)
      head :ok  # Already processed
      return
    end

    # Process webhook
    ActiveRecord::Base.transaction do
      process_webhook(params)
      ProcessedWebhook.create!(idempotency_key: idempotency_key)
    end

    head :ok
  end
end
```

**Webhook Headers:**

Each delivery includes these headers:
- `X-Webhook-Idempotency-Key`: Unique key for this event (use for deduplication)
- `X-Webhook-Delivery-Id`: Unique ID for this specific delivery attempt
- `X-Webhook-Attempt`: Current attempt number (1, 2, 3, etc.)
- `X-Webhook-Signature`: HMAC signature for verification
- `X-Webhook-Event`: Event type (e.g., "order.completed")
- `X-Webhook-Timestamp`: ISO 8601 timestamp

**Best Practices:**

1. Store idempotency keys in your database with a unique constraint
2. Process webhooks in a database transaction
3. Return 200 OK for already-processed webhooks
4. Consider adding a TTL/expiration for old idempotency keys (e.g., 24 hours)

## How It Compares

### vs. webhook_system (Most Popular)

| Feature | webhook_system | Webhookable |
|---------|---------------|-------------|
| Setup complexity | High (custom DSL) | Low (zero config) |
| Job backend | Sidekiq only | Any ActiveJob backend |
| Database schema | Required specific schema | Flexible migrations |
| API simplicity | Complex | Simple |
| Testing tools | Limited | Comprehensive |
| Maintenance | Stale | Active |

**When to use webhook_system**: If you need advanced features like custom processors and have a complex webhook architecture.

**When to use Webhookable**: If you want production-ready webhooks without the complexity.

### vs. hookable (Lightweight)

<!-- ✅ FIXED: Removed unprofessional dismissiveness - replaced "Never/Always" with respectful comparison -->

| Feature | hookable | Webhookable |
|---------|----------|-------------|
| Retry logic | ❌ | ✅ |
| Signatures | ❌ | ✅ |
| Delivery tracking | ❌ | ✅ |
| Production ready | ⚠️ Limited | ✅ |
| Maintained | ⚠️ Last updated 2019 | ✅ |

**When to use hookable**: For simple projects where you can implement retry logic yourself and maintenance status isn't a concern.

**When to use Webhookable**: When you need production-ready webhooks with built-in reliability, security, and observability.

### vs. Svix (Managed Service)

<!-- ✅ FIXED: More balanced comparison acknowledging Svix's legitimate advantages -->

| Feature | Svix | Webhookable |
|---------|------|-------------|
| Deployment | Managed SaaS | Self-hosted |
| Data location | External service | Your infrastructure |
| Cost model | Per-event pricing | Free (self-hosted costs) |
| Maintenance | Fully managed | You maintain |
| UI/Dashboard | Professional UI | Basic (v0.2 roadmap) |
| Customization | Limited to API | Full code control |

**When to use Svix**:
- You want a managed service with professional support
- You need a polished UI for non-technical stakeholders
- You prefer predictable per-event pricing over infrastructure management
- You value not maintaining webhook infrastructure

**When to use Webhookable**:
- You want full control over webhook logic and data flow
- You have Rails expertise and prefer self-hosted solutions
- You want zero recurring costs beyond infrastructure
- You need deep customization beyond what APIs provide

Both are valid choices for different contexts. The best option depends on your team's preferences and constraints.

## Architecture

Webhookable uses a simple, reliable architecture:

1. **Webhook Event**: Created when you trigger a webhook
2. **Webhook Deliveries**: Created for each subscribed endpoint
3. **Background Job**: Delivers webhook via ActiveJob
4. **Retry Logic**: Automatic exponential backoff on failures
5. **Signature**: HMAC-SHA256 signature included in headers

```
trigger_webhook(:completed)
    ↓
Create WebhookEvent
    ↓
Create WebhookDelivery (for each endpoint)
    ↓
Enqueue WebhookDeliveryJob
    ↓
HTTP POST with signature
    ↓
Success → Done
Failure → Retry with exponential backoff
```

## Configuration Options

```ruby
Webhookable.configure do |config|
  # Maximum retry attempts for failed deliveries
  config.max_retry_attempts = 5

  # Initial retry delay in seconds (exponential backoff)
  config.initial_retry_delay = 60

  # Maximum retry delay cap
  config.max_retry_delay = 3600

  # HTTP request timeout
  config.timeout = 30

  # Secret key for signatures (defaults to Rails secret_key_base)
  config.secret_key_base = Rails.application.secret_key_base

  # Enable webhook inbox for testing
  config.enable_inbox = Rails.env.development?

  # Custom logger
  config.logger = Rails.logger

  # Custom user agent
  config.user_agent = "MyApp Webhooks"
end
```

## Requirements

- Ruby >= 3.0
- Rails >= 6.1 (ActiveRecord, ActiveJob, ActiveSupport)
- Any ActiveJob backend (Sidekiq, Solid Queue, Delayed Job, GoodJob, etc.)

## Roadmap

- **v0.2**: Customer-facing delivery log UI (mountable engine)
- **v0.3**: Rate limiting to prevent overwhelming customer endpoints
- **v0.4**: Webhook event filtering and transformation
- **v0.5**: Batch webhook delivery support

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run Rubocop
bundle exec rubocop

# Generate coverage report
bundle exec rspec --format documentation
open coverage/index.html
```

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Security

<!-- ✅ FIXED: Removed unverified email addresses, using GitHub for security reporting -->

For security concerns, please see [SECURITY.md](SECURITY.md) or report via [GitHub Security Advisories](https://github.com/magnusfremont/webhookable/security/advisories).

## Support

- **Issues & Questions**: [GitHub Issues](https://github.com/magnusfremont/webhookable/issues)
- **General Discussion**: [GitHub Discussions](https://github.com/magnusfremont/webhookable/discussions)

## Credits

Created and maintained by [Magnus Fremont](https://github.com/magnusfremont).

Special thanks to the Ruby and Rails communities for inspiration and foundational tools.

---

<!-- ✅ FIXED: Toned down marketing-heavy CTA, focused on community contribution -->

## Community

Enjoying Webhookable? Consider:
- ⭐ [Starring the repo](https://github.com/magnusfremont/webhookable) to help others discover it
- 🐛 [Reporting issues](https://github.com/magnusfremont/webhookable/issues) to improve it for everyone
- 🤝 [Contributing](CONTRIBUTING.md) features or fixes

[View on GitHub](https://github.com/magnusfremont/webhookable) | [View on RubyGems](https://rubygems.org/gems/webhookable)
