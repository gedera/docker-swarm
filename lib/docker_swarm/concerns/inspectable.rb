# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Inspectable
      extend ActiveSupport::Concern

      def inspect
        inspection = if respond_to?(:ID) && ID.present?
                       "ID: #{ID}"
        else
                       "not persisted"
        end

        # Intentar añadir el nombre si existe
        name_attr = attributes["Name"] || (respond_to?(:Name) ? Name : nil)
        inspection += ", Name: #{name_attr}" if name_attr.present?

        # Intentar añadir la imagen para servicios/contenedores
        spec = attributes["Spec"] || (respond_to?(:Spec) ? Spec : nil)
        image = spec&.dig("TaskTemplate", "ContainerSpec", "Image") || attributes["Image"] || (respond_to?(:Image) ? Image : nil)
        inspection += ", Image: #{image}" if image.present?

        "#<#{self.class.name} #{inspection}>"
      end
    end
  end
end
