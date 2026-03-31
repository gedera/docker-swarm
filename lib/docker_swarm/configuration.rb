# frozen_string_literal: true

require "logger"

module DockerSwarm
  class Configuration
    attr_accessor :socket_path, :logger, :log_level,
                  :read_timeout, :write_timeout, :connect_timeout,
                  :max_retries

    def initialize
      @socket_path = "unix:///var/run/docker.sock"
      @logger = Logger.new($stdout)
      @log_level = Logger::INFO
      @read_timeout = 60
      @write_timeout = 60
      @connect_timeout = 10
      @max_retries = 3
    end
  end
end
