# frozen_string_literal: true

module DockerSwarm
  class Node < Base
    include Concerns::Updatable
    include Concerns::Deletable
  end
end
