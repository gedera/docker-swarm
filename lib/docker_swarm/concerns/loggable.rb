# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Loggable
      extend ActiveSupport::Concern

      # Fetches logs for the resource
      # @param query_params [Hash] Query parameters for the logs endpoint (stdout, stderr, follow, etc.)
      # @return [String] The raw log stream
      def logs(query_params = { stdout: 1, stderr: 1 })
        Api.request(action: self.class.routes[:logs], arguments: { id: self.ID }, query_params: query_params)
      end
    end
  end
end
