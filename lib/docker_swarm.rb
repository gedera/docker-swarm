# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "active_model"
require "excon"
require "json"
require "logger"

require_relative "docker_swarm/version"
require_relative "docker_swarm/errors"
require_relative "docker_swarm/middleware/request_encoder"
require_relative "docker_swarm/middleware/response_json_parser"
require_relative "docker_swarm/middleware/error_handler"
require_relative "docker_swarm/connection"
require_relative "docker_swarm/api"
require_relative "docker_swarm/base"
require_relative "docker_swarm/concerns/creatable"
require_relative "docker_swarm/concerns/updatable"
require_relative "docker_swarm/concerns/deletable"

# Models
require_relative "docker_swarm/models/swarm"
require_relative "docker_swarm/models/system"
require_relative "docker_swarm/models/service"
require_relative "docker_swarm/models/node"
require_relative "docker_swarm/models/task"
require_relative "docker_swarm/models/container"
require_relative "docker_swarm/models/image"
require_relative "docker_swarm/models/network"
require_relative "docker_swarm/models/config"
require_relative "docker_swarm/models/secret"
require_relative "docker_swarm/models/volume"

module DockerSwarm
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def connection
      configure unless configuration
      @connection ||= Connection.new(configuration.socket_path, configuration.logger)
    end

    def request(options = {})
      connection.request(options)
    end
  end

  class Configuration
    attr_accessor :socket_path, :logger

    def initialize
      @socket_path = "unix:///var/run/docker.sock"
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end
