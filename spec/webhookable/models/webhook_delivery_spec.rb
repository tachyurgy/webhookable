require "spec_helper"

RSpec.describe Webhookable::WebhookDelivery do
  let(:endpoint) { create(:webhook_endpoint) }
  let(:event) { create(:webhook_event) }
  let(:delivery) { create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event) }

  describe "validations" do
    it "requires status" do
      delivery = build(:webhook_delivery, status: nil)
      expect(delivery).not_to be_valid
    end

    it "validates status inclusion" do
      delivery = build(:webhook_delivery, status: "invalid")
      expect(delivery).not_to be_valid
    end

    it "validates attempt_count is non-negative" do
      delivery = build(:webhook_delivery, attempt_count: -1)
      expect(delivery).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:pending) { create(:webhook_delivery, status: "pending") }
    let!(:successful) { create(:webhook_delivery, status: "success") }
    let!(:failed) { create(:webhook_delivery, status: "failed") }

    describe ".pending" do
      it "returns pending deliveries" do
        expect(described_class.pending).to include(pending)
        expect(described_class.pending).not_to include(successful, failed)
      end
    end

    describe ".successful" do
      it "returns successful deliveries" do
        expect(described_class.successful).to include(successful)
        expect(described_class.successful).not_to include(pending, failed)
      end
    end

    describe ".failed" do
      it "returns failed deliveries" do
        expect(described_class.failed).to include(failed)
        expect(described_class.failed).not_to include(pending, successful)
      end
    end

    describe ".ready_for_retry" do
      it "returns pending deliveries ready for retry" do
        ready = create(:webhook_delivery, status: "pending", next_retry_at: 1.minute.ago)
        not_ready = create(:webhook_delivery, status: "pending", next_retry_at: 1.hour.from_now)

        results = described_class.ready_for_retry
        expect(results).to include(ready)
        expect(results).not_to include(not_ready)
      end
    end
  end

  describe "#mark_success!" do
    it "updates status to success" do
      delivery.mark_success!(response_code: 200)
      expect(delivery.status).to eq("success")
      expect(delivery.response_code).to eq(200)
    end

    it "clears error and retry information" do
      delivery.update!(error_message: "error", next_retry_at: 1.hour.from_now)
      delivery.mark_success!(response_code: 200)

      expect(delivery.error_message).to be_nil
      expect(delivery.next_retry_at).to be_nil
    end

    it "records response details" do
      delivery.mark_success!(
        response_code: 200,
        response_body: "OK",
        response_headers: { "content-type" => "application/json" }
      )

      expect(delivery.response_code).to eq(200)
      expect(delivery.response_body).to eq("OK")
      expect(delivery.response_headers).to eq({ "content-type" => "application/json" })
    end
  end

  describe "#mark_failed!" do
    it "keeps status as pending if should retry" do
      delivery.update!(attempt_count: 1)
      delivery.mark_failed!(error_message: "Connection failed")

      expect(delivery.status).to eq("pending")
      expect(delivery.error_message).to eq("Connection failed")
      expect(delivery.next_retry_at).not_to be_nil
    end

    it "sets status to failed if max retries reached" do
      delivery.update!(attempt_count: 5)
      delivery.mark_failed!(error_message: "Connection failed")

      expect(delivery.status).to eq("failed")
      expect(delivery.next_retry_at).to be_nil
    end
  end

  describe "#should_retry?" do
    it "returns true if attempts below max" do
      delivery.update!(attempt_count: 2)
      expect(delivery.should_retry?).to be(true)
    end

    it "returns false if attempts at max" do
      delivery.update!(attempt_count: 5)
      expect(delivery.should_retry?).to be(false)
    end
  end

  describe "#calculate_next_retry_at" do
    it "uses exponential backoff" do
      delivery.update!(attempt_count: 0)
      next_retry = delivery.calculate_next_retry_at
      expect(next_retry).to be_within(5.seconds).of(60.seconds.from_now)

      delivery.update!(attempt_count: 1)
      next_retry = delivery.calculate_next_retry_at
      expect(next_retry).to be_within(5.seconds).of(120.seconds.from_now)

      delivery.update!(attempt_count: 2)
      next_retry = delivery.calculate_next_retry_at
      expect(next_retry).to be_within(5.seconds).of(240.seconds.from_now)
    end

    it "caps at max_retry_delay" do
      delivery.update!(attempt_count: 20)
      next_retry = delivery.calculate_next_retry_at
      expect(next_retry).to be_within(5.seconds).of(3600.seconds.from_now)
    end
  end

  describe "#build_request_headers" do
    it "includes required webhook headers" do
      headers = delivery.build_request_headers

      expect(headers["Content-Type"]).to eq("application/json")
      expect(headers["User-Agent"]).to include("Webhookable")
      expect(headers["X-Webhook-Signature"]).to start_with("sha256=")
      expect(headers["X-Webhook-Event"]).to eq(event.event_type)
      expect(headers["X-Webhook-Delivery-Id"]).to eq(delivery.id.to_s)
      expect(headers["X-Webhook-Timestamp"]).not_to be_nil
    end
  end
end
