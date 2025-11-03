module Webhookable
  class WebhookEndpoint < ActiveRecord::Base
    self.table_name = "webhook_endpoints"

    has_many :webhook_deliveries, dependent: :destroy

    validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
    validates :secret, presence: true, on: :update

    before_validation :generate_secret, on: :create

    scope :enabled, -> { where(enabled: true) }
    scope :for_event, ->(event_type) do
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
        where("events @> ?", [event_type].to_json)
      else
        # SQLite and other databases - filter in Ruby
        all.select { |endpoint| endpoint.subscribed_to?(event_type) }
      end
    end

    # Check if this endpoint is subscribed to a specific event
    def subscribed_to?(event_type)
      events.include?(event_type.to_s)
    end

    # Enable the endpoint
    def enable!
      update!(enabled: true)
    end

    # Disable the endpoint
    def disable!
      update!(enabled: false)
    end

    # Get successful deliveries count
    def successful_deliveries_count
      webhook_deliveries.where(status: "success").count
    end

    # Get failed deliveries count
    def failed_deliveries_count
      webhook_deliveries.where(status: "failed").count
    end

    # Calculate success rate as percentage
    def success_rate
      total = webhook_deliveries.count
      return 0.0 if total.zero?

      (successful_deliveries_count.to_f / total * 100).round(2)
    end

    private

    def generate_secret
      self.secret ||= SecureRandom.hex(32)
    end
  end
end
