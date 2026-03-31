# frozen_string_literal: true

module DockerSwarm
  class System < Base
    def self.resource_name
      "system"
    end

    def self.info
      Api.request(action: routes[:info])
    end

    def self.version
      Api.request(action: routes[:version])
    end

    def self.up
      Api.request(action: routes[:up])
    end

    def self.df
      Api.request(action: routes[:df])
    end
  end
end
