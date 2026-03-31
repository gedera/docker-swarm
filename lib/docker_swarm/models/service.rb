# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Service
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Service
  class Service < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable
    include Concerns::Loggable
  end
end
