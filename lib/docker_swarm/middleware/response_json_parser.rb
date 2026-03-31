# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class ResponseJSONParser < Excon::Middleware::Base
      def response_call(env)
        if env[:response]
          body = env[:response][:body]
          headers = env[:response][:headers] || {}

          if body && !body.empty? && headers["Content-Type"]&.include?("application/json")
            begin
              parsed = JSON.parse(body)
              env[:response][:body] = parsed.is_a?(Hash) ? parsed.with_indifferent_access : parsed
            rescue JSON::ParserError
              # Keep original body if parsing fails
            end
          end
        end
        
        @stack.response_call(env)
      end
    end
  end
end
