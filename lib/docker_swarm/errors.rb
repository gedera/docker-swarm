# frozen_string_literal: true

module DockerSwarm
  class Error < StandardError; end

  class Error
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

  # Aliases para permitir acceso directo DockerSwarm::Conflict
  BadRequest          = Error::BadRequest
  Unauthorized        = Error::Unauthorized
  Forbidden           = Error::Forbidden
  NotFound            = Error::NotFound
  NotAcceptable       = Error::NotAcceptable
  RequestTimeout      = Error::RequestTimeout
  Conflict            = Error::Conflict
  UnprocessableEntity = Error::UnprocessableEntity
  InternalServerError = Error::InternalServerError
  BadGateway          = Error::BadGateway
  ServiceUnavailable  = Error::ServiceUnavailable
  GatewayTimeout      = Error::GatewayTimeout
  TooManyRequests     = Error::TooManyRequests
  Communication       = Error::Communication

  # Módulo Errors para compatibilidad adicional
  module Errors
    def self.const_missing(name)
      if ::DockerSwarm::Error.const_defined?(name)
        ::DockerSwarm::Error.const_get(name)
      else
        super
      end
    end
  end
end
