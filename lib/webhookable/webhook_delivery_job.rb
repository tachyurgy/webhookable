module Webhookable
  # Background job for delivering webhooks asynchronously
  # Uses ActiveJob for compatibility with any queue backend
  class WebhookDeliveryJob < ActiveJob::Base
    queue_as :webhooks

    # Note: We handle retries ourselves in the Delivery class
    # This retry_on is a fallback for unexpected job failures
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(webhook_delivery_id)
      webhook_delivery = Webhookable::WebhookDelivery.find(webhook_delivery_id)
      Webhookable::Delivery.deliver(webhook_delivery)
    rescue ActiveRecord::RecordNotFound => e
      # Delivery was deleted, nothing to do
      Webhookable.logger.warn("WebhookDelivery #{webhook_delivery_id} not found: #{e.message}")
    end
  end
end
