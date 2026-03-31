# frozen_string_literal: true

module DockerSwarm
  module Middleware
    class RequestEncoder < Excon::Middleware::Base
      def request_call(env)
        if env[:body] && !env[:body].is_a?(String)
          content_type = (env[:headers]["Content-Type"] || env[:headers][:content_type]).to_s
          env[:body] = serialize_body(env[:body], content_type)
          
          if content_type.blank? || content_type.include?("application/json")
            env[:headers]["Content-Type"] ||= "application/json"
          end
        end
        @stack.request_call(env)
      end

      private

      def serialize_body(body, content_type)
        if content_type.include?("application/x-www-form-urlencoded")
          URI.encode_www_form(body)
        elsif content_type.include?("multipart/form-data")
          body
        else
          body.to_json
        end
      end
    end
  end
end
