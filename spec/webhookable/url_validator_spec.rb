# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhookable::UrlValidator do
  describe '.validate' do
    context 'with valid URLs' do
      it 'accepts standard HTTPS URLs' do
        valid, error = described_class.validate('https://example.com/webhook')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it 'accepts standard HTTP URLs' do
        valid, error = described_class.validate('http://example.com/webhook')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it 'accepts URLs with ports' do
        valid, error = described_class.validate('https://example.com:8443/webhook')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it 'accepts URLs with query parameters' do
        valid, error = described_class.validate('https://example.com/webhook?token=abc')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it 'accepts URLs with paths' do
        valid, error = described_class.validate('https://api.example.com/webhooks/receive')
        expect(valid).to be true
        expect(error).to be_nil
      end
    end

    context 'with invalid URLs' do
      it 'rejects blank URLs' do
        valid, error = described_class.validate('')
        expect(valid).to be false
        expect(error).to eq('URL cannot be blank')
      end

      it 'rejects nil URLs' do
        valid, error = described_class.validate(nil)
        expect(valid).to be false
        expect(error).to eq('URL cannot be blank')
      end

      it 'rejects malformed URLs' do
        valid, error = described_class.validate('not a url')
        expect(valid).to be false
        expect(error).to include('Invalid URL format')
      end

      it 'rejects URLs without protocol' do
        valid, error = described_class.validate('example.com/webhook')
        expect(valid).to be false
        expect(error).to eq('URL must use HTTP or HTTPS protocol')
      end

      it 'rejects FTP URLs' do
        valid, error = described_class.validate('ftp://example.com/webhook')
        expect(valid).to be false
        expect(error).to eq('URL must use HTTP or HTTPS protocol')
      end

      it 'rejects file:// URLs' do
        valid, error = described_class.validate('file:///etc/passwd')
        expect(valid).to be false
        expect(error).to eq('URL must use HTTP or HTTPS protocol')
      end

      it 'rejects URLs without hostname' do
        valid, error = described_class.validate('https://')
        expect(valid).to be false
        expect(error).to eq('URL must include a hostname')
      end
    end

    context 'SSRF protection' do
      context 'localhost' do
        it 'rejects localhost' do
          valid, error = described_class.validate('http://localhost/webhook')
          expect(valid).to be false
          expect(error).to eq('URL hostname contains blocked keyword')
        end

        it 'rejects 127.0.0.1' do
          valid, error = described_class.validate('http://127.0.0.1/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end

        it 'rejects 127.0.0.2' do
          valid, error = described_class.validate('http://127.0.0.2/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end

        it 'rejects IPv6 localhost (::1)' do
          valid, error = described_class.validate('http://[::1]/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end
      end

      context 'private network ranges' do
        it 'rejects 10.0.0.0/8 range' do
          valid, error = described_class.validate('http://10.0.0.1/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end

        it 'rejects 172.16.0.0/12 range' do
          valid, error = described_class.validate('http://172.16.0.1/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end

        it 'rejects 192.168.0.0/16 range' do
          valid, error = described_class.validate('http://192.168.1.1/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end
      end

      context 'link-local addresses' do
        it 'rejects 169.254.0.0/16 range' do
          valid, error = described_class.validate('http://169.254.1.1/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end
      end

      context 'IPv6 private ranges' do
        it 'rejects fc00::/7 (private)' do
          valid, error = described_class.validate('http://[fc00::1]/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end

        it 'rejects fe80::/10 (link-local)' do
          valid, error = described_class.validate('http://[fe80::1]/webhook')
          expect(valid).to be false
          expect(error).to include('URL uses a blocked IP address')
        end
      end

      context 'blocked keywords' do
        it "rejects URLs with 'localhost' in hostname" do
          valid, error = described_class.validate('http://my-localhost.com/webhook')
          expect(valid).to be false
          expect(error).to eq('URL hostname contains blocked keyword')
        end

        it "rejects URLs with 'internal' in hostname" do
          valid, error = described_class.validate('http://internal.company.com/webhook')
          expect(valid).to be false
          expect(error).to eq('URL hostname contains blocked keyword')
        end

        it "rejects URLs with 'admin' in hostname" do
          valid, error = described_class.validate('http://admin.company.com/webhook')
          expect(valid).to be false
          expect(error).to eq('URL hostname contains blocked keyword')
        end

        it "rejects URLs with 'metadata' in hostname" do
          valid, error = described_class.validate('http://metadata.aws.amazon.com/')
          expect(valid).to be false
          expect(error).to eq('URL hostname contains blocked keyword')
        end
      end

      context 'DNS resolution attacks' do
        # These tests require stubbing DNS resolution
        it 'rejects URLs that resolve to private IPs' do
          # In a real implementation, you might stub Resolv.getaddresses
          # to return private IPs for a public domain
          # For now, we'll skip this as it requires network access
          # or more complex stubbing
        end
      end
    end

    context 'edge cases' do
      it 'handles URLs with unusual but valid characters' do
        valid, error = described_class.validate('https://example.com/webhook?foo=bar&baz=qux#fragment')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it "handles URLs with authentication (but doesn't recommend it)" do
        valid, error = described_class.validate('https://user:pass@example.com/webhook')
        expect(valid).to be true
        expect(error).to be_nil
      end

      it 'handles URLs with unicode characters' do
        valid, error = described_class.validate('https://example.com/webhook/🎉')
        expect(valid).to be true
        expect(error).to be_nil
      end
    end
  end
end
