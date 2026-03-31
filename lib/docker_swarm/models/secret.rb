# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Secret
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Secret
  class Secret < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
