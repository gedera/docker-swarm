# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Task
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Task
  class Task < Base
    include Concerns::Loggable
  end
end
