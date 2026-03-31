# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class RequestEncoder < Excon::Middleware::Base
      def request_call(env)
        if env[:body] && env[:body].is_a?(Hash)
          env[:body] = env[:body].to_json
          env[:headers]["Content-Type"] ||= "application/json"
        end
        @stack.request_call(env)
      end
    end
  end
end
