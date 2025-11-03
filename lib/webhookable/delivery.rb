require "httparty"

module Webhookable
  class Delivery
    include HTTParty

    class << self
      # Deliver a webhook
      def deliver(webhook_delivery)
        new(webhook_delivery).deliver
      end
    end

    attr_reader :webhook_delivery

    def initialize(webhook_delivery)
      @webhook_delivery = webhook_delivery
    end

    def deliver
      return handle_inbox_mode if Webhookable.configuration.enable_inbox

      webhook_delivery.increment_attempt!

      begin
        response = send_webhook

        if response.success?
          handle_success(response)
        else
          handle_failure(response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      instrument_delivery
    end

    private

    def send_webhook
      HTTParty.post(
        webhook_delivery.url,
        body: webhook_delivery.payload.to_json,
        headers: webhook_delivery.build_request_headers,
        timeout: Webhookable.configuration.timeout,
        follow_redirects: false
      )
    end

    def handle_success(response)
      webhook_delivery.mark_success!(
        response_code: response.code,
        response_body: truncate_response(response.body),
        response_headers: response.headers.to_h
      )

      Webhookable.logger.info(
        "Webhook delivered successfully: delivery_id=#{webhook_delivery.id} " \
        "endpoint=#{webhook_delivery.url} status=#{response.code}"
      )
    end

    def handle_failure(response)
      error_message = "HTTP #{response.code}: #{response.message}"

      webhook_delivery.mark_failed!(
        error_message: error_message,
        response_code: response.code,
        response_body: truncate_response(response.body),
        response_headers: response.headers.to_h
      )

      if webhook_delivery.should_retry?
        schedule_retry
      else
        log_permanent_failure(error_message)
      end
    end

    def handle_error(error)
      error_message = "#{error.class}: #{error.message}"

      webhook_delivery.mark_failed!(
        error_message: error_message
      )

      if webhook_delivery.should_retry?
        schedule_retry
      else
        log_permanent_failure(error_message)
      end
    end

    def schedule_retry
      Webhookable::WebhookDeliveryJob.set(
        wait_until: webhook_delivery.next_retry_at
      ).perform_later(webhook_delivery.id)

      Webhookable.logger.warn(
        "Webhook delivery failed, will retry: delivery_id=#{webhook_delivery.id} " \
        "attempt=#{webhook_delivery.attempt_count} " \
        "next_retry=#{webhook_delivery.next_retry_at}"
      )
    end

    def log_permanent_failure(error_message)
      Webhookable.logger.error(
        "Webhook delivery permanently failed: delivery_id=#{webhook_delivery.id} " \
        "endpoint=#{webhook_delivery.url} error=#{error_message}"
      )
    end

    def handle_inbox_mode
      inbox_entry = InboxEntry.create!(
        webhook_delivery: webhook_delivery,
        payload: webhook_delivery.payload,
        headers: webhook_delivery.build_request_headers,
        url: webhook_delivery.url
      )

      webhook_delivery.mark_success!(
        response_code: 200,
        response_body: "Stored in inbox (development mode)"
      )

      Webhookable.logger.debug(
        "Webhook stored in inbox: delivery_id=#{webhook_delivery.id}"
      )

      inbox_entry
    end

    def instrument_delivery
      webhook_delivery.reload # Ensure we have fresh data
      ActiveSupport::Notifications.instrument(
        "webhook.delivered",
        delivery_id: webhook_delivery.id,
        status: webhook_delivery.status,
        attempt_count: webhook_delivery.attempt_count,
        endpoint_id: webhook_delivery.webhook_endpoint_id,
        event_type: webhook_delivery.webhook_event.event_type
      )
    end

    def truncate_response(body, max_length: 10_000)
      return nil if body.nil?
      return body if body.length <= max_length

      "#{body[0...max_length]}... (truncated)"
    end
  end
end
