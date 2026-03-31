# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Image
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Image
  class Image < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
