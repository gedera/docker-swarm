# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "active_model"
require "excon"
require "json"
require "logger"

module DockerSwarm
  class << self
    attr_accessor :configuration

    def configure
      @configuration ||= Configuration.new
      yield(@configuration) if block_given?
      
      if @configuration.logger.respond_to?(:level=)
        @configuration.logger.level = @configuration.log_level
      end
      
      @connection = nil
    end

    def connection
      configure unless @configuration
      @connection ||= Connection.new(@configuration.socket_path, @configuration.logger)
    end

    def request(options = {})
      connection.request(options)
    end
  end
end

# Primero cargamos la configuración porque la clase DockerSwarm la usa arriba
require_relative "docker_swarm/configuration"
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
