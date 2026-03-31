# frozen_string_literal: true

module DockerSwarm
  # Access point for Docker Swarm cluster information
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Swarm
  class Swarm < Base
    # Override resource name to match API endpoint
    # @return [String]
    def self.resource_name
      "swarm"
    end

    # Returns information about the swarm
    # @return [Hash] Raw swarm data
    def self.show
      Api.request(action: routes[:show])
    end
  end
end
