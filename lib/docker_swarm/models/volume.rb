# frozen_string_literal: true

module DockerSwarm
  class Volume < Base
    include Concerns::Creatable
    include Concerns::Deletable

    def self.all(filters = {})
      response = _fetch_all(filters)
      return [] if response.blank?
      
      data = response.is_a?(Hash) ? response["Volumes"] : response
      Array(data).map { |item| new(item) }
    end
  end
end
