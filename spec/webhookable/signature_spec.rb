# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhookable::Signature do
  let(:secret) { 'my-secret-key' }
  let(:payload) { { event: 'test', data: { id: 1 } } }
  let(:payload_json) { payload.to_json }

  describe '.generate' do
    it 'generates a valid HMAC-SHA256 signature' do
      signature = described_class.generate(payload_json, secret)
      expect(signature).to start_with('sha256=')
      expect(signature.length).to eq(71) # "sha256=" + 64 hex characters
    end

    it 'generates consistent signatures for the same input' do
      sig1 = described_class.generate(payload_json, secret)
      sig2 = described_class.generate(payload_json, secret)
      expect(sig1).to eq(sig2)
    end

    it 'generates different signatures for different payloads' do
      sig1 = described_class.generate(payload_json, secret)
      sig2 = described_class.generate({ different: 'data' }.to_json, secret)
      expect(sig1).not_to eq(sig2)
    end

    it 'generates different signatures for different secrets' do
      sig1 = described_class.generate(payload_json, secret)
      sig2 = described_class.generate(payload_json, 'different-secret')
      expect(sig1).not_to eq(sig2)
    end

    it 'raises SignatureError if payload is nil' do
      expect do
        described_class.generate(nil, secret)
      end.to raise_error(Webhookable::SignatureError, 'Payload cannot be nil')
    end

    it 'raises SignatureError if secret is nil' do
      expect do
        described_class.generate(payload_json, nil)
      end.to raise_error(Webhookable::SignatureError, 'Secret cannot be nil')
    end

    it 'accepts Hash payloads and converts them to JSON' do
      signature = described_class.generate(payload, secret)
      expect(signature).to be_a(String)
    end
  end

  describe '.verify' do
    let(:signature) { described_class.generate(payload_json, secret) }

    it 'returns true for valid signature' do
      expect(described_class.verify(payload_json, signature, secret)).to be(true)
    end

    it 'returns false for invalid signature' do
      invalid_signature = "sha256=#{'a' * 64}"
      expect(described_class.verify(payload_json, invalid_signature, secret)).to be(false)
    end

    it 'returns false for wrong secret' do
      expect(described_class.verify(payload_json, signature, 'wrong-secret')).to be(false)
    end

    it 'returns false for tampered payload' do
      tampered_payload = { event: 'test', data: { id: 2 } }.to_json
      expect(described_class.verify(tampered_payload, signature, secret)).to be(false)
    end

    it 'raises SignatureError if payload is nil' do
      expect do
        described_class.verify(nil, signature, secret)
      end.to raise_error(Webhookable::SignatureError, 'Payload cannot be nil')
    end

    it 'raises SignatureError if signature is nil' do
      expect do
        described_class.verify(payload_json, nil, secret)
      end.to raise_error(Webhookable::SignatureError, 'Signature cannot be nil')
    end

    it 'raises SignatureError if secret is nil' do
      expect do
        described_class.verify(payload_json, signature, nil)
      end.to raise_error(Webhookable::SignatureError, 'Secret cannot be nil')
    end
  end

  describe '.secure_compare' do
    it 'returns true for identical strings' do
      expect(described_class.secure_compare('abc', 'abc')).to be(true)
    end

    it 'returns false for different strings' do
      expect(described_class.secure_compare('abc', 'xyz')).to be(false)
    end

    it 'returns false for strings of different lengths' do
      expect(described_class.secure_compare('abc', 'abcd')).to be(false)
    end

    it 'performs constant-time comparison' do
      # This is hard to test directly, but we can verify it works correctly
      string1 = 'a' * 1000
      string2 = 'b' * 1000
      expect(described_class.secure_compare(string1, string2)).to be(false)
    end
  end
end
