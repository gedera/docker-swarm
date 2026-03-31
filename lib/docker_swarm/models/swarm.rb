# frozen_string_literal: true

module DockerSwarm
  class Swarm < Base
    def self.resource_name
      "swarm"
    end

    def self.show
      Api.request(action: routes[:show])
    end
  end
end
