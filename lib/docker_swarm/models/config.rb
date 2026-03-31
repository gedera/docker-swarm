# frozen_string_literal: true

module DockerSwarm
  class Config < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
