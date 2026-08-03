# frozen_string_literal: true

module DockerSwarm
  # Helper module to centralize logging logic and formatting
  module LogHelper
    # `data` se matchea con \b para que `Data` (Secret/Config) se filtre
    # pero `metadata` u otras claves no caigan en falso positivo.
    # `auth` cubre headers de autenticación (`X-Registry-Auth`, `Authorization`), case-insensitive.
    SENSITIVE_KEYS = /password|pass|passwd|secret|token|api_key|auth|\bdata\b/i.freeze
    FILTERED = "[FILTERED]"

    # Un elemento de `Env` de Docker: `"CLAVE=VALOR"`. El `[^=]+` a la izquierda
    # evita partir en un `=` que pertenezca al valor (los valores base64 y las
    # URLs los traen), y `/m` cubre un valor multilínea — una clave PEM pasada
    # por variable de entorno.
    KV_STRING = /\A([^=]+)=(.+)\z/m

    # Redacta recursivamente los valores sensibles, a cualquier profundidad
    # (hashes y arrays anidados). No muta la entrada: devuelve copias.
    #
    # Cubre DOS formas, porque el nombre de un secreto no siempre es una clave
    # de hash:
    #
    # 1. **Clave de hash sensible** — `headers: { "X-Registry-Auth" => "<cred>" }`.
    #    Un header sensible puede viajar anidado, y el match por clave de primer
    #    nivel no lo alcanzaba: el hash interno se interpolaba entero.
    # 2. **`"CLAVE=VALOR"` dentro de un String** — el `Env` de un `ContainerSpec`
    #    es un ARRAY DE STRINGS, así que el nombre del secreto vive dentro del
    #    elemento y no como clave. Sin esto, `Env` no matchea {SENSITIVE_KEYS},
    #    sus elementos caen al `else`, y **el valor de todo secreto pasado por
    #    variable de entorno se loguea entero** — en `request_success`, o sea en
    #    el camino feliz, a nivel INFO.
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
      when String
        redact_kv_string(value)
      else
        value
      end
    end

    # Redacta el VALOR de un String con forma `"CLAVE=VALOR"` cuando la clave es
    # sensible, conservando el nombre: saber QUÉ secreto apareció es diagnóstico
    # útil, su valor no.
    #
    # Un String que no tiene esa forma —o cuya clave no es sensible— vuelve tal
    # cual, así que `"RAILS_LOG_LEVEL=info"` y cualquier mensaje de error quedan
    # intactos.
    #
    # @param str [String]
    # @return [String] con el valor reemplazado por {FILTERED}, o el original
    def self.redact_kv_string(str)
      match = KV_STRING.match(str)
      return str unless match && match[1].match?(SENSITIVE_KEYS)

      "#{match[1]}=#{FILTERED}"
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
