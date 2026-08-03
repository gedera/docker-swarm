# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Container
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Container
  class Container < Base
    include Concerns::Creatable
    include Concerns::Deletable
    include Concerns::Loggable

    # +POST /containers/create+ toma el nombre por query string. En el body Docker lo
    # **descarta en silencio** y responde +201+: el container nace con nombre aleatorio
    # y la adopción por nombre determinista en un reintento no encuentra nada, así que
    # el reintento duplica. Ver ADR-025 cláusula 1.
    # @return [Array<String>]
    def self.create_query_params
      %w[name].freeze
    end

    # Starts the container
    # @return [Boolean] true if successful
    def start
      Api.request(action: self.class.routes[:start], arguments: { id: self.ID })
      true
    end

    # Stops the container
    # @return [Boolean] true if successful
    def stop
      Api.request(action: self.class.routes[:stop], arguments: { id: self.ID })
      true
    end
  end
end
