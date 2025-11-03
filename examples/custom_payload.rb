# Example: Custom Webhook Payloads
#
# This example shows how to customize webhook payloads

require 'webhookable'

class Subscription < ApplicationRecord
  include Webhookable::Model
  webhook_events :activated, :cancelled, :payment_failed

  belongs_to :user
  belongs_to :plan

  # Override default payload to customize what gets sent
  def default_webhook_payload
    {
      subscription_id: id,
      status: status,
      plan: {
        name: plan.name,
        price: plan.price,
        billing_period: plan.billing_period
      },
      customer: {
        id: user.id,
        email: user.email,
        company: user.company_name
      },
      current_period_start: current_period_start,
      current_period_end: current_period_end,
      next_billing_date: next_billing_date,
      metadata: {
        environment: Rails.env,
        triggered_at: Time.current.iso8601
      }
    }
  end
end

# Trigger with default payload
subscription = Subscription.find(1)
subscription.trigger_webhook(:activated)

# Or override with custom payload for specific situations
subscription.trigger_webhook(:payment_failed, custom_payload: {
  subscription_id: subscription.id,
  failure_reason: "Card declined",
  retry_scheduled_at: 1.day.from_now,
  amount_cents: subscription.plan.price_cents
})
