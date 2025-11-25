# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhookable::Configuration do
  describe '#initialize' do
    it 'sets default max_retry_attempts to 5' do
      expect(subject.max_retry_attempts).to eq(5)
    end

    it 'sets default initial_retry_delay to 60 seconds' do
      expect(subject.initial_retry_delay).to eq(60)
    end

    it 'sets default max_retry_delay to 3600 seconds' do
      expect(subject.max_retry_delay).to eq(3600)
    end

    it 'sets default timeout to 30 seconds' do
      expect(subject.timeout).to eq(30)
    end

    it 'sets default enable_inbox to false' do
      expect(subject.enable_inbox).to be(false)
    end

    it 'sets a user_agent' do
      expect(subject.user_agent).to include('Webhookable')
    end

    it 'initializes a logger' do
      expect(subject.logger).to be_a(Logger)
    end
  end

  describe 'custom configuration' do
    it 'allows setting custom values' do
      config = described_class.new
      config.max_retry_attempts = 10
      config.timeout = 60
      config.enable_inbox = true

      expect(config.max_retry_attempts).to eq(10)
      expect(config.timeout).to eq(60)
      expect(config.enable_inbox).to be(true)
    end
  end
end
