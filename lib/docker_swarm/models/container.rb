# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Container
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Container
  class Container < Base
    include Concerns::Deletable
    include Concerns::Loggable

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
