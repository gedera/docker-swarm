# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Updatable
      extend ActiveSupport::Concern

      def update(new_attributes = {})
        assign_attributes(new_attributes) if new_attributes.present?
        return false unless valid?

        Api.request(
          action: self.class.routes[:update],
          arguments: { id: self.ID },
          query_params: { version: self.Version&.dig("Index") },
          payload: payload_for_docker
        )

        true
      end
    end
  end
end
