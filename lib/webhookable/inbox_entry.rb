module Webhookable
  class InboxEntry < ActiveRecord::Base
    self.table_name = "webhookable_inbox_entries"

    belongs_to :webhook_delivery, optional: true

    validates :url, presence: true
    validates :payload, presence: true

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
