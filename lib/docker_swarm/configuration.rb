# frozen_string_literal: true

require "logger"

module DockerSwarm
  class Configuration
    attr_accessor :socket_path, :logger, :log_level

    def initialize
      @socket_path = "unix:///var/run/docker.sock"
      @logger = Logger.new($stdout)
      @log_level = Logger::INFO
    end
  end
end
