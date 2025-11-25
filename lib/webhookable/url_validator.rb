# frozen_string_literal: true

require "uri"
require "ipaddr"
require "resolv"
require "cgi"

module Webhookable
  # Validates webhook URLs to prevent SSRF attacks
  class UrlValidator
    # IP ranges that should be blocked
    BLOCKED_IP_RANGES = [
      IPAddr.new("0.0.0.0/8"),       # "This network"
      IPAddr.new("127.0.0.0/8"),     # Loopback
      IPAddr.new("10.0.0.0/8"),      # Private network
      IPAddr.new("172.16.0.0/12"),   # Private network
      IPAddr.new("192.168.0.0/16"),  # Private network
      IPAddr.new("169.254.0.0/16"),  # Link-local
      IPAddr.new("100.64.0.0/10"),   # Shared address space (Carrier-grade NAT)
      IPAddr.new("224.0.0.0/4"),     # Multicast
      IPAddr.new("240.0.0.0/4"),     # Reserved
      IPAddr.new("::1/128"),         # IPv6 loopback
      IPAddr.new("fc00::/7"),        # IPv6 private
      IPAddr.new("fe80::/10")        # IPv6 link-local
    ].freeze

    BLOCKED_HOSTNAMES = %w[
      localhost
      local
      internal
      intranet
      private
      admin
      metadata
    ].freeze

    class << self
      # Validate a webhook URL for security
      # Returns [valid?, error_message]
      def validate(url_string)
        return [false, "URL cannot be blank"] if url_string.blank?

        # Parse the URL (encode if needed for unicode support)
        begin
          # Try to parse as-is first
          uri = URI.parse(url_string)
        rescue URI::InvalidURIError => e
          # If it fails due to unicode, try encoding the path/query
          begin
            # Split URL into base and path
            return [false, "Invalid URL format: #{e.message}"] unless url_string =~ %r{^(https?://[^/]+)(.*)$}

            base = ::Regexp.last_match(1)
            path = ::Regexp.last_match(2)
            encoded_url = base + URI.encode_www_form_component(path).gsub("+", "%20")
            uri = URI.parse(encoded_url)
          rescue StandardError => encoding_error
            return [false, "Invalid URL format: #{encoding_error.message}"]
          end
        end

        # Check protocol
        return [false, "URL must use HTTP or HTTPS protocol"] unless %w[http https].include?(uri.scheme&.downcase)

        # Check for missing host
        return [false, "URL must include a hostname"] if uri.host.blank?

        # Check for blocked hostnames
        hostname_lower = uri.host.downcase
        if BLOCKED_HOSTNAMES.any? { |blocked| hostname_lower.include?(blocked) }
          return [false, "URL hostname contains blocked keyword"]
        end

        # Resolve hostname to IP addresses
        begin
          ip_addresses = Resolv.getaddresses(uri.host)
        rescue Resolv::ResolvError => e
          # If DNS resolution fails, reject it to prevent DNS rebinding attacks
          return [false, "Unable to resolve hostname: #{e.message}"]
        end

        # Reject if no IP addresses were resolved
        return [false, "Hostname does not resolve to any IP addresses"] if ip_addresses.empty?

        # Check if any resolved IP is in a blocked range
        ip_addresses.each do |ip_string|
          ip = IPAddr.new(ip_string)
          return [false, "URL resolves to a blocked IP address (#{ip_string})"] if blocked_ip?(ip)
        rescue IPAddr::InvalidAddressError
          # Skip invalid IPs
          next
        end

        # Check for IP literals in the hostname
        if uri.host =~ /^\d+\.\d+\.\d+\.\d+$/ || uri.host.include?(":")
          begin
            ip = IPAddr.new(uri.host)
            return [false, "URL uses a blocked IP address"] if blocked_ip?(ip)
          rescue IPAddr::InvalidAddressError
            # Not an IP literal, continue
          end
        end

        [true, nil]
      end

      private

      def blocked_ip?(ip)
        BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
      end
    end
  end
end
