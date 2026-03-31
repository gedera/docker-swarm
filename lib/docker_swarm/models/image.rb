# frozen_string_literal: true

module DockerSwarm
  class Image < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
