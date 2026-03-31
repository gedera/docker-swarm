# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Service
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Service
  class Service < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable

    validate :validate_name_presence

    # Fetches logs for the service
    # @param query_params [Hash] Query parameters for the logs endpoint (stdout, stderr, follow, etc.)
    # @return [String] The raw log stream
    def logs(query_params = { stdout: 1, stderr: 1 })
      Api.request(action: self.class.routes[:logs], arguments: { id: self.ID }, query_params: query_params)
    end

    private

    def validate_name_presence
      name = attributes["Name"] || (respond_to?(:Name) ? Name : nil)
      errors.add(:Name, "can't be blank") if name.blank?
    end
  end
end
