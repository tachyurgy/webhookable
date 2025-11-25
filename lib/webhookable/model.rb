# frozen_string_literal: true

module Webhookable
  module Model
    extend ActiveSupport::Concern

    class_methods do
      # Define webhook events for this model
      # Usage: webhook_events :created, :updated, :deleted
      def webhook_events(*events)
        @webhook_events ||= []
        @webhook_events.concat(events.map(&:to_s))

        events.each do |event|
          define_webhook_trigger_method(event)
        end
      end

      # Get all defined webhook events
      def webhookable_events
        @webhook_events || []
      end

      # Define method to trigger webhook
      def define_webhook_trigger_method(event)
        define_method("trigger_webhook_#{event}") do |custom_payload: nil|
          trigger_webhook(event, custom_payload: custom_payload)
        end
      end
    end

    # Trigger a webhook event
    def trigger_webhook(event_type, custom_payload: nil)
      event_type = event_type.to_s

      unless self.class.webhookable_events.include?(event_type)
        raise ArgumentError, "Event '#{event_type}' is not defined for #{self.class.name}"
      end

      payload = custom_payload || default_webhook_payload

      # Create webhook event
      webhook_event = Webhookable::WebhookEvent.create!(
        event_type: event_type,
        eventable: self,
        payload: payload
      )

      # Create deliveries for all subscribed endpoints
      deliveries_count = webhook_event.create_deliveries!

      # Enqueue deliveries
      webhook_event.enqueue_deliveries! if deliveries_count.positive?

      # Instrument the event
      ActiveSupport::Notifications.instrument(
        "webhook.triggered",
        event_type: event_type,
        model: self.class.name,
        model_id: id,
        deliveries_count: deliveries_count
      )

      webhook_event
    end

    # Default payload for webhooks
    # Override this method in your model to customize the payload
    def default_webhook_payload
      as_json
    end

    # Get all webhook events for this record
    def webhook_events
      Webhookable::WebhookEvent.where(eventable: self)
    end

    # Get all webhook deliveries for this record
    def webhook_deliveries
      Webhookable::WebhookDelivery
        .joins(:webhook_event)
        .where(webhook_events: {eventable: self})
    end
  end
end
