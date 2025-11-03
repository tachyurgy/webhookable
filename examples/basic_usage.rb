# Example: Basic Webhookable Usage
#
# This example demonstrates the simplest possible webhook setup

require 'webhookable'

# 1. Include Webhookable in your model
class Order < ApplicationRecord
  include Webhookable::Model
  webhook_events :completed, :cancelled
end

# 2. Create a webhook endpoint (typically done by your customers via UI)
endpoint = WebhookEndpoint.create!(
  url: "https://customer.example.com/webhooks",
  events: ["order.completed"]
)

# 3. Trigger a webhook
order = Order.create!(status: 'pending', total: 99.99)
order.update!(status: 'completed')
order.trigger_webhook(:completed)

# That's it! The webhook will be delivered automatically with:
# - Automatic retries on failure
# - HMAC-SHA256 signature
# - Full delivery tracking
