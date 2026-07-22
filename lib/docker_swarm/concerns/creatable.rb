# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Creatable
      extend ActiveSupport::Concern

      class_methods do
        # @param attributes [Hash] atributos Docker (hash posicional braceado)
        # @param opts [Hash] keywords: atributos sueltos históricos + opción reservada
        #   +registry_auth+ (credencial para X-Registry-Auth). El resto se pliega como atributos.
        def create(attributes = {}, **opts)
          registry_auth = opts.delete(:registry_auth)
          resource = new(attributes.merge(opts))
          resource.save(registry_auth: registry_auth)
          resource
        end
      end

      # @param registry_auth [String, nil] credencial opaca para el header X-Registry-Auth
      def save(registry_auth: nil)
        return false unless valid?
        return update(registry_auth: registry_auth) if persisted?

        headers, = RegistryAuth.resolve(registry_auth: registry_auth)
        response = Api.request(
          action: self.class.routes[:create],
          payload: payload_for_docker,
          headers: headers
        )

        self.ID = response["ID"] || response["Id"] || response["Name"]
        reload
        true
      end
    end
  end
end
