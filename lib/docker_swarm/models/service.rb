# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Service
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Service
  class Service < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable
    include Concerns::Loggable

    # Restarts the service by incrementing ForceUpdate, which causes
    # Docker to recreate all tasks.
    #
    # @return [Boolean] true if the restart was triggered successfully
    def restart
      current = self.Spec&.dig("TaskTemplate", "ForceUpdate").to_i
      update(Spec: { TaskTemplate: { ForceUpdate: current + 1 } })
    end
  end
end
