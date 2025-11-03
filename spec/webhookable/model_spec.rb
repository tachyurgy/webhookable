require "spec_helper"

RSpec.describe Webhookable::Model do
  let(:order) { create(:order) }

  describe ".webhook_events" do
    it "defines webhook events" do
      expect(Order.webhookable_events).to include("completed", "cancelled", "refunded")
    end

    it "creates trigger methods" do
      expect(order).to respond_to(:trigger_webhook_completed)
      expect(order).to respond_to(:trigger_webhook_cancelled)
      expect(order).to respond_to(:trigger_webhook_refunded)
    end
  end

  describe "#trigger_webhook" do
    let!(:endpoint) { create(:webhook_endpoint, events: ["order.completed"], url: "https://example.com/webhook") }

    it "creates a webhook event" do
      expect {
        order.trigger_webhook(:completed)
      }.to change { Webhookable::WebhookEvent.count }.by(1)

      event = Webhookable::WebhookEvent.last
      expect(event.event_type).to eq("completed")
      expect(event.eventable).to eq(order)
    end

    it "creates deliveries for subscribed endpoints" do
      initial_count = Webhookable::WebhookDelivery.count
      order.trigger_webhook(:completed)
      expect(Webhookable::WebhookDelivery.count).to eq(initial_count + 1)
    end

    it "raises error for undefined events" do
      expect {
        order.trigger_webhook(:invalid_event)
      }.to raise_error(ArgumentError, /Event 'invalid_event' is not defined/)
    end

    it "accepts custom payload" do
      custom_payload = { "custom" => "data" }
      event = order.trigger_webhook(:completed, custom_payload: custom_payload)

      expect(event.payload).to eq(custom_payload)
    end

    it "uses default payload when not provided" do
      event = order.trigger_webhook(:completed)
      expect(event.payload).to include("id" => order.id)
    end

    it "instruments the webhook trigger" do
      instrumented = false

      ActiveSupport::Notifications.subscribe("webhook.triggered") do |name, start, finish, id, payload|
        instrumented = true if payload[:event_type] == "completed" && payload[:model] == "Order"
      end

      order.trigger_webhook(:completed)

      expect(instrumented).to be(true)
    end
  end

  describe "generated trigger methods" do
    let!(:endpoint) { create(:webhook_endpoint, events: ["order.completed"]) }

    it "triggers webhook with the correct event" do
      expect {
        order.trigger_webhook_completed
      }.to change { Webhookable::WebhookEvent.where(event_type: "completed").count }.by(1)
    end

    it "accepts custom payload" do
      event = order.trigger_webhook_completed(custom_payload: { "test" => "data" })
      expect(event.payload).to eq({ "test" => "data" })
    end
  end

  describe "#webhook_events" do
    it "returns webhook events for the record" do
      order.trigger_webhook(:completed)
      order.trigger_webhook(:cancelled)

      events = order.webhook_events
      expect(events.count).to eq(2)
      expect(events.pluck(:event_type)).to match_array(["completed", "cancelled"])
    end
  end

  describe "#webhook_deliveries" do
    it "returns webhook deliveries for the record" do
      create(:webhook_endpoint, events: ["order.completed"])
      event = order.trigger_webhook(:completed)

      deliveries = order.webhook_deliveries
      expect(deliveries.count).to be >= 1
      expect(deliveries.first.webhook_event).to eq(event)
    end
  end
end
