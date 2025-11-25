# frozen_string_literal: true

require "openssl"

module Webhookable
  module Signature
    module_function

    # Generate HMAC-SHA256 signature for payload
    def generate(payload, secret)
      raise SignatureError, "Payload cannot be nil" if payload.nil?
      raise SignatureError, "Secret cannot be nil" if secret.nil?

      payload_string = payload.is_a?(String) ? payload : payload.to_json
      hmac = OpenSSL::HMAC.hexdigest("SHA256", secret, payload_string)
      "sha256=#{hmac}"
    end

    # Verify HMAC-SHA256 signature
    def verify(payload, signature, secret)
      raise SignatureError, "Payload cannot be nil" if payload.nil?
      raise SignatureError, "Signature cannot be nil" if signature.nil?
      raise SignatureError, "Secret cannot be nil" if secret.nil?

      expected_signature = generate(payload, secret)
      secure_compare(expected_signature, signature)
    end

    # Constant-time string comparison to prevent timing attacks
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      r = 0
      i = -1

      b.each_byte { |byte| r |= byte ^ l[i += 1] }
      r.zero?
    end
  end
end
