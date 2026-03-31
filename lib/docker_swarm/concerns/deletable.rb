# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Deletable
      extend ActiveSupport::Concern

      class_methods do
        def destroy(id)
          Api.request(action: routes[:destroy], arguments: { id: id })
          true
        rescue Errors::NotFound
          nil
        end
      end

      def destroy
        self.class.destroy(self.ID)
      end
    end
  end
end
