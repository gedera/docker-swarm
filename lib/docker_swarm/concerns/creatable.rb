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

        # Atributos que el Engine toma por **query string** en el +create+, no en el body.
        # Un atributo declarado acá viaja en la URL y se excluye del payload: mandarlo en
        # el body no le da error a Docker, lo **descarta en silencio**.
        # Override en el modelo que lo necesite (p. ej. +name+ en {DockerSwarm::Container}).
        # @return [Array<String>] nombres de atributo
        def create_query_params
          [].freeze
        end
      end

      # @param registry_auth [String, nil] credencial opaca para el header X-Registry-Auth
      def save(registry_auth: nil)
        return false unless valid?
        return update(registry_auth: registry_auth) if persisted?

        headers, = RegistryAuth.resolve(registry_auth: registry_auth)
        response = Api.request(
          action: self.class.routes[:create],
          query_params: query_params_for_docker,
          payload: payload_for_docker.except(*self.class.create_query_params),
          headers: headers
        )

        self.ID = response["ID"] || response["Id"] || response["Name"]
        reload
        true
      end

      # Los +create_query_params+ que este recurso tiene seteados, listos para la URL.
      # @return [Hash{Symbol => Object}] vacío si el modelo no declara ninguno
      def query_params_for_docker
        keys = self.class.create_query_params
        return {} if keys.empty?

        attributes.slice(*keys).compact.symbolize_keys
      end
    end
  end
end
