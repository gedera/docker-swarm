# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class ErrorHandler < Excon::Middleware::Base
      def response_call(env)
        return @stack.response_call(env) unless env[:response]

        status = env[:response][:status]
        body = env[:response][:body]

        case status
        when 200..299
          # Continuar normalmente
        when 400 then raise Errors::BadRequest, error_message(body)
        when 401 then raise Errors::Unauthorized, error_message(body)
        when 403 then raise Errors::Forbidden, error_message(body)
        when 404 then raise Errors::NotFound, error_message(body)
        when 406 then raise Errors::NotAcceptable, error_message(body)
        when 408 then raise Errors::RequestTimeout, error_message(body)
        when 409 then raise Errors::Conflict, error_message(body)
        when 422 then raise Errors::UnprocessableEntity, body
        when 429 then raise Errors::TooManyRequests, error_message(body)
        when 500 then raise Errors::InternalServerError, error_message(body)
        when 502 then raise Errors::BadGateway, error_message(body)
        when 503 then raise Errors::ServiceUnavailable, error_message(body)
        when 504 then raise Errors::GatewayTimeout, error_message(body)
        else
          raise Errors::Error, "HTTP #{status}: #{error_message(body)}"
        end

        @stack.response_call(env)
      end

      private

      def error_message(body)
        if body.is_a?(Hash)
          body["message"] || body["error"] || body.to_json
        else
          body.to_s
        end
      end
    end
  end
end
