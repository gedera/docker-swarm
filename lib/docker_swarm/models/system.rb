# frozen_string_literal: true

module DockerSwarm
  # Access point for Docker System information and operations
  # @see https://docs.docker.com/engine/api/v1.41/#tag/System
  class System < Base
    # Override resource name to match API endpoint
    # @return [String]
    def self.resource_name
      "system"
    end

    # Returns system information
    # @return [Hash]
    def self.info
      Api.request(action: routes[:info])
    end

    # Returns Docker version information
    # @return [Hash]
    def self.version
      Api.request(action: routes[:version])
    end

    # Checks if the Docker daemon is responding
    # @return [String] "OK" if up
    def self.up
      Api.request(action: routes[:up])
    end

    # Returns system-wide data usage information
    # @return [Hash]
    def self.df
      Api.request(action: routes[:df])
    end
  end
end
