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

      endpoints.each do |endpoint|
        webhook_deliveries.create!(
          webhook_endpoint: endpoint,
          status: "pending"
        )
      end

      webhook_deliveries.count
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
