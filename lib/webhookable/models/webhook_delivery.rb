# frozen_string_literal: true

module Webhookable
  class WebhookDelivery < ActiveRecord::Base
    self.table_name = "webhook_deliveries"

    belongs_to :webhook_endpoint
    belongs_to :webhook_event

    validates :status, presence: true, inclusion: {in: %w[pending success failed]}
    validates :attempt_count, numericality: {greater_than_or_equal_to: 0}

    scope :pending, -> { where(status: "pending") }
    scope :successful, -> { where(status: "success") }
    scope :failed, -> { where(status: "failed") }
    scope :ready_for_retry, -> { where(status: "pending").where("next_retry_at <= ?", Time.current) }

    # Mark delivery as successful
    def mark_success!(response_code:, response_body: nil, response_headers: {})
      update!(
        status: "success",
        response_code: response_code,
        response_body: response_body,
        response_headers: response_headers,
        last_attempt_at: Time.current,
        next_retry_at: nil,
        error_message: nil
      )
    end

    # Mark delivery as failed
    def mark_failed!(error_message:, response_code: nil, response_body: nil, response_headers: {})
      attrs = {
        error_message: error_message,
        response_code: response_code,
        response_body: response_body,
        response_headers: response_headers,
        last_attempt_at: Time.current
      }

      if should_retry?
        attrs[:next_retry_at] = calculate_next_retry_at
      else
        attrs[:status] = "failed"
        attrs[:next_retry_at] = nil
      end

      update!(attrs)
    end

    # Increment attempt count
    def increment_attempt!
      increment!(:attempt_count)
    end

    # Check if delivery should be retried
    def should_retry?
      attempt_count < Webhookable.configuration.max_retry_attempts
    end

    # Calculate next retry time with exponential backoff
    def calculate_next_retry_at
      delay = Webhookable.configuration.initial_retry_delay * (2**attempt_count)
      delay = [delay, Webhookable.configuration.max_retry_delay].min
      delay.seconds.from_now
    end

    # Check if delivery is ready for retry
    def ready_for_retry?
      status == "pending" && next_retry_at.present? && next_retry_at <= Time.current
    end

    # Get the payload to send
    def payload
      webhook_event.payload
    end

    # Get the URL to deliver to
    def url
      webhook_endpoint.url
    end

    # Get the secret for signature generation
    def secret
      webhook_endpoint.secret
    end

    # Get request headers for delivery
    def build_request_headers
      payload_json = payload.to_json
      signature = Webhookable::Signature.generate(payload_json, secret)

      {
        "Content-Type" => "application/json",
        "User-Agent" => Webhookable.configuration.user_agent,
        "X-Webhook-Signature" => signature,
        "X-Webhook-Event" => webhook_event.event_type,
        "X-Webhook-Delivery-Id" => id.to_s,
        "X-Webhook-Attempt" => attempt_count.to_s,
        "X-Webhook-Timestamp" => Time.current.iso8601,
        "X-Webhook-Idempotency-Key" => webhook_event.idempotency_key
      }
    end
  end
end
