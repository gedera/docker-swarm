# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Inspectable
      extend ActiveSupport::Concern

      def inspect
        return "#<#{self.class.name} not persisted>" unless persisted?

        parts = []
        id_val = send(:ID)
        parts << "ID: #{id_val}" if respond_to?(:ID) && id_val.present?
        name_val = send(:Name)
        parts << "Name: #{name_val}" if respond_to?(:Name) && name_val.present?
        created_val = send(:CreatedAt)
        parts << "CreatedAt: #{created_val}" if respond_to?(:CreatedAt) && created_val.present?
        updated_val = send(:UpdatedAt)
        parts << "UpdatedAt: #{updated_val}" if respond_to?(:UpdatedAt) && updated_val.present?
        version_val = send(:Version)
        parts << "Version: #{version_val}" if respond_to?(:Version) && version_val.present?

        spec_val = send(:Spec)
        if respond_to?(:Spec) && spec_val.present?
          spec_str = spec_val.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
          parts << "Spec(#{spec_str})"
        end

        "#<#{self.class.name} #{parts.join(", ")}>"
      end
    end
  end
end
