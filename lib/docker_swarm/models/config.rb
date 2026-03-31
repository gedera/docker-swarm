# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Config
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Config
  class Config < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
