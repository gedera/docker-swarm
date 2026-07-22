# frozen_string_literal: true

module DockerSwarm
  # Traduce las opciones de autenticación de registry privado a los canales de
  # transporte de la Docker Engine API, sin tocar el payload ni el estado del modelo:
  #
  # - +registry_auth+      -> header +X-Registry-Auth+ (credencial opaca base64url).
  # - +registry_auth_from+ -> query +registryAuthFrom+ (+spec+ | +previous-spec+),
  #   fuente de credencial a reusar en un update cuando el header NO está presente.
  #
  # Son mutuamente excluyentes: Docker define +registryAuthFrom+ como la fuente a usar
  # solo si +X-Registry-Auth+ no viaja. Si el caller pasa ambos, se corta con un error
  # local claro antes de la request, en vez de derivar la ambigüedad al Engine.
  #
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Service/operation/ServiceUpdate
  module RegistryAuth
    HEADER = "X-Registry-Auth"
    QUERY = :registryAuthFrom
    FROM_VALUES = %w[spec previous-spec].freeze

    module_function

    # @param registry_auth [String, nil] credencial opaca para el header X-Registry-Auth
    # @param registry_auth_from [String, nil] "spec" | "previous-spec"; excluyente con registry_auth
    # @return [Array(Hash, Hash)] par [headers, query_params] a mergear en la request
    #   (cada uno vacío cuando su opción no vino)
    # @raise [ArgumentError] si vienen ambos juntos o si registry_auth_from es inválido
    def resolve(registry_auth: nil, registry_auth_from: nil)
      validate!(registry_auth, registry_auth_from)

      headers = registry_auth ? { HEADER => registry_auth } : {}
      query = registry_auth_from ? { QUERY => registry_auth_from } : {}

      [ headers, query ]
    end

    def validate!(registry_auth, registry_auth_from)
      if registry_auth && registry_auth_from
        raise ArgumentError, "registry_auth y registry_auth_from son mutuamente excluyentes: pasá uno u otro"
      end

      return if registry_auth_from.nil? || FROM_VALUES.include?(registry_auth_from)

      raise ArgumentError,
            "registry_auth_from inválido: #{registry_auth_from.inspect} (válidos: #{FROM_VALUES.join(', ')})"
    end
  end
end
