# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Node
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Node
  class Node < Base
    include Concerns::Updatable
    include Concerns::Deletable
  end
end
