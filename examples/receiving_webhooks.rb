# frozen_string_literal: true

# Example: Receiving and Verifying Webhooks
#
# This example shows how your customers should handle incoming webhooks

require 'webhookable'

# In a Rails controller that receives webhooks
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    # 1. Read the raw payload
    payload = request.body.read

    # 2. Get the signature from headers
    signature = request.headers['X-Webhook-Signature']
    event_type = request.headers['X-Webhook-Event']
    delivery_id = request.headers['X-Webhook-Delivery-Id']

    # 3. Verify the signature
    secret = ENV['WEBHOOK_SECRET'] # Your endpoint's secret

    unless Webhookable.verify_signature(payload, signature, secret)
      Rails.logger.warn("Invalid webhook signature: delivery_id=#{delivery_id}")
      return head :unauthorized
    end

    # 4. Parse and process the webhook
    data = JSON.parse(payload)

    case event_type
    when 'order.completed'
      handle_order_completed(data)
    when 'order.cancelled'
      handle_order_cancelled(data)
    when 'subscription.activated'
      handle_subscription_activated(data)
    else
      Rails.logger.warn("Unknown webhook event: #{event_type}")
    end

    # 5. Return success (important!)
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error("Invalid JSON in webhook: #{e.message}")
    head :bad_request
  rescue StandardError => e
    # Log the error but still return success to prevent retries
    Rails.logger.error("Error processing webhook: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    head :ok
  end

  private

  def handle_order_completed(data)
    order_id = data['id']
    # Process the completed order
    Rails.logger.info("Order #{order_id} completed: #{data.inspect}")
  end

  def handle_order_cancelled(data)
    order_id = data['id']
    # Process the cancelled order
    Rails.logger.info("Order #{order_id} cancelled: #{data.inspect}")
  end

  def handle_subscription_activated(data)
    subscription_id = data['subscription_id']
    # Process the activated subscription
    Rails.logger.info("Subscription #{subscription_id} activated: #{data.inspect}")
  end
end

# In config/routes.rb
# post '/webhooks', to: 'webhooks#receive'
