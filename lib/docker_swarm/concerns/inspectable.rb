# frozen_string_literal: true

module DockerSwarm
  module Concerns
    module Inspectable
      extend ActiveSupport::Concern

      def inspect
        return "#<#{self.class.name} not persisted>" unless persisted?

        parts = []
        parts << "ID: #{ID}" if respond_to?(:ID) && ID.present?
        parts << "Name: #{Name}" if respond_to?(:Name) && Name.present?
        parts << "CreatedAt: #{CreatedAt}" if respond_to?(:CreatedAt) && CreatedAt.present?
        parts << "UpdatedAt: #{UpdatedAt}" if respond_to?(:UpdatedAt) && UpdatedAt.present?
        parts << "Version: #{Version}" if respond_to?(:Version) && Version.present?

        if respond_to?(:Spec) && Spec.present?
          spec_str = Spec.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
          parts << "Spec(#{spec_str})"
        end

        "#<#{self.class.name} #{parts.join(", ")}>"
      end
    end
  end
end
