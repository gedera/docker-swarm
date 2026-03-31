# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class ErrorHandler < Excon::Middleware::Base
      def response_call(env)
        return @stack.response_call(env) unless env[:response]

        status = env[:response][:status]
        body = env[:response][:body]

        return @stack.response_call(env) if (200..299).include?(status)

        error_msg = error_message(body)
        log_business_error(env, status, error_msg)

        case status
        when 400 then raise ::DockerSwarm::BadRequest, error_msg
        when 401 then raise ::DockerSwarm::Unauthorized, error_msg
        when 403 then raise ::DockerSwarm::Forbidden, error_msg
        when 404 then raise ::DockerSwarm::NotFound, error_msg
        when 406 then raise ::DockerSwarm::NotAcceptable, error_msg
        when 408 then raise ::DockerSwarm::RequestTimeout, error_msg
        when 409 then raise ::DockerSwarm::Conflict, error_msg
        when 422 then raise ::DockerSwarm::UnprocessableEntity, body
        when 429 then raise ::DockerSwarm::TooManyRequests, error_msg
        when 500 then raise ::DockerSwarm::InternalServerError, error_msg
        when 502 then raise ::DockerSwarm::BadGateway, error_msg
        when 503 then raise ::DockerSwarm::ServiceUnavailable, error_msg
        when 504 then raise ::DockerSwarm::GatewayTimeout, error_msg
        else
          raise ::DockerSwarm::Error, "HTTP #{status}: #{error_msg}"
        end
      end

      private

      def log_business_error(env, status, message)
        logger = env[:logger]
        return unless logger

        begin
          kv_string = LogHelper.format_kv({
            component: "docker_swarm.middleware.error_handler",
            event: "business_error",
            source: "http",
            status: status,
            message: message,
            method: env[:method],
            path: env[:path]
          })

          logger.error(kv_string)
        rescue
          # Resilience: logging should not crash the app
        end
      end

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
