# frozen_string_literal: true

require "logger"

module DockerSwarm
  class Configuration
    attr_accessor :socket_path, :logger, :log_level
    attr_reader :read_timeout, :write_timeout, :connect_timeout, :max_retries

    def initialize
      @socket_path = "unix:///var/run/docker.sock"
      @logger = Logger.new($stdout)
      @log_level = Logger::INFO
      @read_timeout = 60.0
      @write_timeout = 60.0
      @connect_timeout = 10.0
      @max_retries = 3
    end

    def read_timeout=(val)
      @read_timeout = val&.to_f
    end

    def write_timeout=(val)
      @write_timeout = val&.to_f
    end

    def connect_timeout=(val)
      @connect_timeout = val&.to_f
    end

    def max_retries=(val)
      @max_retries = val&.to_i
    end
  end
end
