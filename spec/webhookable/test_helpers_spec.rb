require "spec_helper"

RSpec.describe Webhookable::TestHelpers do
  include Webhookable::TestHelpers

  let(:order) { create(:order) }
  let!(:endpoint) { create(:webhook_endpoint, events: ["order.completed"]) }

  describe "#clear_webhooks" do
    it "clears all webhook data" do
      order.trigger_webhook(:completed)

      clear_webhooks

      expect(Webhookable::WebhookEvent.count).to eq(0)
      expect(Webhookable::WebhookDelivery.count).to eq(0)
    end
  end

  describe "#assert_webhook_triggered" do
    it "passes when webhook was triggered" do
      order.trigger_webhook(:completed)
      expect { assert_webhook_triggered(:completed, model: order) }.not_to raise_error
    end

    it "fails when webhook was not triggered" do
      expect { assert_webhook_triggered(:completed, model: order) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "#refute_webhook_triggered" do
    it "passes when webhook was not triggered" do
      expect { refute_webhook_triggered(:completed, model: order) }.not_to raise_error
    end

    it "fails when webhook was triggered" do
      order.trigger_webhook(:completed)
      expect { refute_webhook_triggered(:completed, model: order) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "#last_webhook_event" do
    it "returns the most recent webhook event" do
      order.trigger_webhook(:completed)
      order.trigger_webhook(:cancelled)

      event = last_webhook_event
      expect(event.event_type).to eq("cancelled")
    end

    it "can filter by event type" do
      order.trigger_webhook(:completed)
      order.trigger_webhook(:cancelled)

      event = last_webhook_event(:completed)
      expect(event.event_type).to eq("completed")
    end
  end

  describe "RSpec matchers" do
    describe "have_triggered_webhook" do
      it "matches when webhook was triggered" do
        order.trigger_webhook(:completed)
        expect(order).to have_triggered_webhook(:completed)
      end

      it "does not match when webhook was not triggered" do
        expect(order).not_to have_triggered_webhook(:completed)
      end
    end

    describe "enqueue_webhook" do
      it "matches when block triggers webhook" do
        expect {
          order.trigger_webhook(:completed)
        }.to enqueue_webhook(:completed)
      end

      it "does not match when block does not trigger webhook" do
        expect {
          # nothing
        }.not_to enqueue_webhook(:completed)
      end
    end
  end
end
