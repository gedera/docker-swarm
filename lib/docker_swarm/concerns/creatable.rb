# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Creatable
      extend ActiveSupport::Concern

      class_methods do
        def create(attributes = {})
          resource = new(attributes)
          resource.save
          resource
        end
      end

      def save
        return false unless valid?
        return update if persisted?

        response = Api.request(
          action: self.class.routes[:create],
          payload: payload_for_docker
        )

        self.ID = response["ID"] || response["Id"] || response["Name"]
        reload
        true
      end
    end
  end
end
