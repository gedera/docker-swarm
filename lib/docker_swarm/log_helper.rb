# frozen_string_literal: true

module DockerSwarm
  # Helper module to centralize logging logic and formatting
  module LogHelper
    # `data` se matchea con \b para que `Data` (Secret/Config) se filtre
    # pero `metadata` u otras claves no caigan en falso positivo.
    # `auth` cubre headers de autenticación (`X-Registry-Auth`, `Authorization`), case-insensitive.
    SENSITIVE_KEYS = /password|pass|passwd|secret|token|api_key|auth|\bdata\b/i.freeze
    FILTERED = "[FILTERED]"

    # Redacta recursivamente los valores cuya CLAVE es sensible, a cualquier
    # profundidad (hashes y arrays anidados). No muta la entrada: devuelve copias.
    #
    # Un header sensible puede viajar anidado (`headers: { "X-Registry-Auth" => "<cred>" }`)
    # y el match por clave de primer nivel no lo alcanzaba — el hash interno se
    # interpolaba entero.
    #
    # @param value [Object] hash, array o escalar
    # @return [Object] copia con los valores sensibles reemplazados por [FILTERED]
    def self.sanitize(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), acc|
          acc[k] = k.to_s.match?(SENSITIVE_KEYS) ? FILTERED : sanitize(v)
        end
      when Array
        value.map { |v| sanitize(v) }
      else
        value
      end
    end

    # Formats a hash into a KV structured string with sensitive data masking
    # @param payload [Hash] The data to format
    # @return [String] KV formatted string
    def self.format_kv(payload)
      sanitize(payload).map do |k, v|
        "#{k}=#{v}"
      end.join(" ")
    rescue
      "event=logging_error"
    end
  end
end
