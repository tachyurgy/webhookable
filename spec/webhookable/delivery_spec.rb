require "spec_helper"

RSpec.describe Webhookable::Delivery do
  let(:endpoint) { create(:webhook_endpoint, url: "https://example.com/webhook") }
  let(:event) { create(:webhook_event) }
  let(:delivery) { create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event) }

  describe ".deliver" do
    before do
      stub_request(:post, "https://example.com/webhook")
        .to_return(status: 200, body: "OK")
    end

    it "delivers webhook successfully" do
      described_class.deliver(delivery)

      expect(delivery.reload.status).to eq("success")
      expect(delivery.response_code).to eq(200)
    end

    it "increments attempt count" do
      expect {
        described_class.deliver(delivery)
      }.to change { delivery.reload.attempt_count }.by(1)
    end

    it "sends correct payload and headers" do
      expected_payload = delivery.payload.to_json

      described_class.new(delivery).deliver

      expect(a_request(:post, "https://example.com/webhook")
        .with(
          body: expected_payload
        ).with { |req|
          req.headers["Content-Type"] == "application/json" &&
          req.headers["X-Webhook-Signature"]&.start_with?("sha256=")
        }
      ).to have_been_made
    end
  end

  describe "handling HTTP responses" do
    context "when request succeeds (2xx)" do
      before do
        stub_request(:post, "https://example.com/webhook")
          .to_return(status: 200, body: "Success")
      end

      it "marks delivery as success" do
        described_class.deliver(delivery)
        expect(delivery.reload.status).to eq("success")
      end

      it "records response details" do
        described_class.deliver(delivery)
        expect(delivery.reload.response_code).to eq(200)
        expect(delivery.response_body).to eq("Success")
      end
    end

    context "when request fails (4xx/5xx)" do
      before do
        stub_request(:post, "https://example.com/webhook")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "marks delivery as failed and schedules retry" do
        described_class.deliver(delivery)
        delivery.reload

        expect(delivery.status).to eq("pending")
        expect(delivery.next_retry_at).not_to be_nil
        expect(delivery.error_message).to include("500")
      end

      context "when max retries reached" do
        before do
          delivery.update!(attempt_count: 5)
        end

        it "marks delivery as permanently failed" do
          described_class.deliver(delivery)
          delivery.reload

          expect(delivery.status).to eq("failed")
          expect(delivery.next_retry_at).to be_nil
        end
      end
    end

    context "when network error occurs" do
      before do
        stub_request(:post, "https://example.com/webhook")
          .to_raise(HTTParty::Error.new("Connection refused"))
      end

      it "marks delivery as failed and schedules retry" do
        described_class.deliver(delivery)
        delivery.reload

        expect(delivery.status).to eq("pending")
        expect(delivery.next_retry_at).not_to be_nil
        expect(delivery.error_message).to include("HTTParty::Error")
      end
    end
  end

  describe "inbox mode" do
    before do
      Webhookable.configuration.enable_inbox = true
    end

    it "stores webhook in inbox instead of delivering" do
      expect {
        described_class.deliver(delivery)
      }.to change { Webhookable::InboxEntry.count }.by(1)

      expect(WebMock).not_to have_requested(:post, "https://example.com/webhook")
    end

    it "marks delivery as successful" do
      described_class.deliver(delivery)
      expect(delivery.reload.status).to eq("success")
    end

    it "stores correct payload and headers" do
      described_class.deliver(delivery)
      inbox_entry = Webhookable::InboxEntry.last

      expect(inbox_entry.payload).to eq(delivery.payload)
      expect(inbox_entry.url).to eq(delivery.url)
      expect(inbox_entry.headers).to include("X-Webhook-Signature")
    end
  end

  describe "instrumentation" do
    before do
      stub_request(:post, "https://example.com/webhook")
        .to_return(status: 200)
    end

    it "instruments webhook delivery" do
      instrumented = false

      ActiveSupport::Notifications.subscribe("webhook.delivered") do |name, start, finish, id, payload|
        instrumented = true if payload[:delivery_id] == delivery.id
      end

      described_class.deliver(delivery)

      expect(instrumented).to be(true)
    end
  end

  describe "response truncation" do
    let(:long_body) { "a" * 15000 }

    before do
      stub_request(:post, "https://example.com/webhook")
        .to_return(status: 200, body: long_body)
    end

    it "truncates long response bodies" do
      described_class.deliver(delivery)
      expect(delivery.reload.response_body.length).to be <= 10050 # 10000 + truncation message
      expect(delivery.response_body).to include("(truncated)")
    end
  end
end
