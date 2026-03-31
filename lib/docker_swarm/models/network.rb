# frozen_string_literal: true

module DockerSwarm
  class Network < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable

    validate :validate_name_presence

    private

    def validate_name_presence
      name = attributes["Name"] || (respond_to?(:Name) ? Name : nil)
      errors.add(:Name, "can't be blank") if name.blank?
    end
  end
end
