# frozen_string_literal: true

module DockerSwarm
  # Helper module to centralize logging logic and formatting
  module LogHelper
    # `data` se matchea con \b para que `Data` (Secret/Config) se filtre
    # pero `metadata` u otras claves no caigan en falso positivo.
    SENSITIVE_KEYS = /password|pass|passwd|secret|token|api_key|auth|\bdata\b/i.freeze

    # Formats a hash into a KV structured string with sensitive data masking
    # @param payload [Hash] The data to format
    # @return [String] KV formatted string
    def self.format_kv(payload)
      payload.map do |k, v|
        val = k.to_s =~ SENSITIVE_KEYS ? "[FILTERED]" : v
        "#{k}=#{val}"
      end.join(" ")
    rescue
      "event=logging_error"
    end
  end
end
