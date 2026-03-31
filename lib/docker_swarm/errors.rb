# frozen_string_literal: true

module DockerSwarm
  class Error < StandardError; end

  module Errors
    class BadRequest < Error; end
    class Unauthorized < Error; end
    class Forbidden < Error; end
    class NotFound < Error; end
    class NotAcceptable < Error; end
    class RequestTimeout < Error; end
    class Conflict < Error; end
    class UnprocessableEntity < Error; end
    class InternalServerError < Error; end
    class BadGateway < Error; end
    class ServiceUnavailable < Error; end
    class GatewayTimeout < Error; end
    class TooManyRequests < Error; end
    class Communication < Error; end
  end
end
