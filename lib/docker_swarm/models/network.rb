# frozen_string_literal: true

module DockerSwarm
  class Network < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable
  end
end
