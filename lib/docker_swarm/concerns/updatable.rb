# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Updatable
      extend ActiveSupport::Concern

      # @param new_attributes [Hash] atributos Docker (hash posicional braceado)
      # @param opts [Hash] keywords: atributos sueltos históricos + opciones reservadas
      #   +registry_auth+ (header X-Registry-Auth) / +registry_auth_from+ (query registryAuthFrom,
      #   excluyente con registry_auth). El resto se pliega como atributos.
      def update(new_attributes = {}, **opts)
        registry_auth = opts.delete(:registry_auth)
        registry_auth_from = opts.delete(:registry_auth_from)
        # Valida (excluyente + enum) y resuelve los canales ANTES de mutar el objeto.
        headers, auth_query = RegistryAuth.resolve(registry_auth: registry_auth, registry_auth_from: registry_auth_from)

        current_version = self.Version&.dig("Index")
        attributes = new_attributes.merge(opts)
        assign_attributes(attributes) if attributes.present?
        return false unless valid?

        Api.request(
          action: self.class.routes[:update],
          arguments: { id: self.ID },
          query_params: { version: current_version }.merge(auth_query),
          payload: payload_for_docker,
          headers: headers
        )

        true
      end
    end
  end
end
