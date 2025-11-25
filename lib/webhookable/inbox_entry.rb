# frozen_string_literal: true

module Webhookable
  class InboxEntry < ActiveRecord::Base
    self.table_name = "webhookable_inbox_entries"

    belongs_to :webhook_delivery, optional: true

    validates :url, presence: true
    validates :payload, presence: true
    validate :validate_url_security

    def validate_url_security
      return if url.blank?

      valid, error_message = UrlValidator.validate(url)
      errors.add(:url, error_message) unless valid
    end

    scope :recent, -> { order(created_at: :desc) }

    # Get the event type from headers
    def event_type
      headers&.dig("X-Webhook-Event")
    end

    # Get the signature from headers
    def signature
      headers&.dig("X-Webhook-Signature")
    end

    # Replay this webhook to its original URL
    def replay!
      # Re-validate URL at replay time to prevent DNS rebinding attacks
      valid, error_message = UrlValidator.validate(url)
      raise SecurityError, "URL validation failed at replay time: #{error_message}" unless valid

      response = HTTParty.post(
        url,
        body: payload.to_json,
        headers: headers,
        timeout: Webhookable.configuration.timeout
      )

      update!(
        replayed_at: Time.current,
        replay_response_code: response.code,
        replay_response_body: response.body
      )

      response.success?
    end

    # Clear all inbox entries
    def self.clear_all!
      delete_all
    end

    # Get entries for a specific event type
    def self.for_event(event_type)
      where("headers ->> 'X-Webhook-Event' = ?", event_type.to_s)
    end
  end
end
