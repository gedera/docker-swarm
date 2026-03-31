# frozen_string_literal: true

module DockerSwarm
  class Connection
    attr_reader :socket_path, :logger

    def initialize(socket_path, logger)
      @socket_path = socket_path
      @logger = logger
    end

    def request(options = {})
      normalized_path = socket_path.sub(/^unix:\/\//, "")
      client(normalized_path).request(options).body
    rescue => e
      if e.is_a?(Excon::Error::Socket)
        raise Errors::Communication, "Docker socket error: #{e.message}"
      else
        raise e
      end
    end
    private

    def client(path)
      @client ||= Excon.new(
        "unix:///",
        socket: path,
        middlewares: [
          Excon::Middleware::ResponseParser,
          Excon::Middleware::RedirectFollower,
          Middleware::RequestEncoder,
          Middleware::ResponseJSONParser,
          Middleware::ErrorHandler
        ]
      )
    end
  end
end
