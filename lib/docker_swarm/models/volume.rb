# frozen_string_literal: true

module DockerSwarm
  class Volume < Base
    include Concerns::Creatable
    include Concerns::Deletable

    def self.root_key
      "Volumes"
    end
  end
end
