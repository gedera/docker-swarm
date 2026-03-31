# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class ResponseJSONParser < Excon::Middleware::Base
      def response_call(env)
        if env[:response]
          body = env[:response][:body]
          headers = env[:response][:headers] || {}

          if body && !body.empty? && headers["Content-Type"]&.include?("application/json")
            env[:response][:body] = parse_json(body)
          end
        end

        @stack.response_call(env)
      end

      private

      def parse_json(body)
        result = body.is_a?(String) ? JSON.parse(body) : body

        case result
        when Hash
          result.with_indifferent_access
        when Array
          result.map { |item| item.is_a?(Hash) ? item.with_indifferent_access : item }
        else
          result
        end
      rescue JSON::ParserError
        body
      end
    end
  end
end
