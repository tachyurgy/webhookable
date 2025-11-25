# frozen_string_literal: true

module Webhookable
  class WebhookEvent < ActiveRecord::Base
    self.table_name = "webhook_events"

    belongs_to :eventable, polymorphic: true
    has_many :webhook_deliveries, dependent: :destroy

    validates :event_type, presence: true
    validates :payload, presence: true
    validates :idempotency_key, presence: true, uniqueness: true

    before_validation :generate_idempotency_key, on: :create

    scope :by_type, ->(type) { where(event_type: type) }
    scope :recent, -> { order(created_at: :desc) }

    # Create webhook deliveries for all subscribed endpoints
    def create_deliveries!
      full_event_name = "#{eventable_type.underscore}.#{event_type}"
      endpoints = WebhookEndpoint.enabled.for_event(full_event_name)
      endpoints = endpoints.to_a unless endpoints.is_a?(ActiveRecord::Relation)

      return 0 if endpoints.empty?

      # Use batch insert for better performance with many endpoints
      timestamp = Time.current
      delivery_data = endpoints.map do |endpoint|
        {
          webhook_event_id: id,
          webhook_endpoint_id: endpoint.id,
          status: "pending",
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      WebhookDelivery.insert_all(delivery_data)
      delivery_data.size
    end

    # Enqueue all pending deliveries
    def enqueue_deliveries!
      webhook_deliveries.where(status: "pending").find_each do |delivery|
        Webhookable::WebhookDeliveryJob.perform_later(delivery.id)
      end
    end

    # Get the full event name (e.g., "order.completed")
    def full_event_name
      "#{eventable_type.underscore}.#{event_type}"
    end

    private

    def generate_idempotency_key
      self.idempotency_key ||= SecureRandom.uuid
    end
  end
end
