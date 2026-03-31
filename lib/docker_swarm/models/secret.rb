# frozen_string_literal: true

module DockerSwarm
  class Secret < Base
    include Concerns::Creatable
    include Concerns::Deletable
  end
end
