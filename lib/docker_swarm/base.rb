# frozen_string_literal: true

module DockerSwarm
  class Base
    include ActiveModel::Model

    class << self
      def resource_name
        name.demodulize.downcase.pluralize
      end

      def routes
        Api::ENDPOINTS[resource_name.to_sym]
      end

      # Key in the JSON response that contains the array of items.
      # Override in subclasses if the API returns a wrapped object (e.g., Volumes).
      # @return [String, nil]
      def root_key
        nil
      end

      def all(filters = {})
        response = _fetch_all(filters)
        return [] if response.blank?

        data = root_key && response.is_a?(Hash) ? response[root_key] : response
        Array(data).map { |item| new(item) }
      end

      def find(id)
        data = Api.request(action: routes[:show], arguments: { id: id })
        new(data)
      rescue Errors::NotFound
        nil
      end

      def where(filters)
        all(filters)
      end

      private

      def _fetch_all(filters = {})
        query = {}

        if filters.present?
          global_params = filters.slice(:all, :force, :limit, :since, :before)
          docker_filters = filters.except(:all, :force, :limit, :since, :before)

          query = global_params

          if docker_filters.any?
            normalized = docker_filters.transform_keys { |k| k.to_s.downcase }
                                       .transform_values { |v| Array(v) }
            query[:filters] = normalized.to_json
          end
        end

        Api.request(action: routes[:index], query_params: query)
      end
    end

    def initialize(attributes = {})
      assign_attributes(attributes) if attributes.present?
      super()
    end

    def assign_attributes(new_attributes)
      return if new_attributes.blank?

      attributes_to_assign = new_attributes.deep_dup

      if attributes_to_assign.is_a?(Hash)
        attributes_to_assign = attributes_to_assign.with_indifferent_access
        normalized_attributes = {}

        attributes_to_assign.each do |key, value|
          normalized_key = key.to_s == "Id" ? "ID" : key.to_s
          _define_dynamic_accessor(normalized_key)

          if normalized_key == "Spec" && respond_to?(:Spec) && self.Spec.is_a?(Hash) && value.is_a?(Hash)
            value = self.Spec.deep_merge(value)
          end

          normalized_attributes[normalized_key] = value
        end

        super(normalized_attributes)
      else
        Array(attributes_to_assign).each do |item|
          next unless item.is_a?(Hash)
          item.each_key { |key| _define_dynamic_accessor(key) }
        end
      end
    end

    def attributes
      instance_values.except("validation_context", "errors", "context_for_validation")
    end

    def serializable_hash(_options = nil)
      attributes
    end

    def as_json(options = nil)
      serializable_hash(options)
    end

    def payload_for_docker
      data = attributes.except("ID", "Id", "Version", "CreatedAt", "UpdatedAt").compact
      return data unless data.key?("Spec")

      spec = data.delete("Spec").deep_dup
      spec.merge!(data)
    end

    def persisted?
      respond_to?(:ID) && self.ID.present?
    end

    def id
      self.ID
    end

    def reload
      fresh = self.class.find(id)
      assign_attributes(fresh.attributes) if fresh
      self
    end

    def method_missing(method_name, *args, &block)
      method_str = method_name.to_s

      if method_str.end_with?("=")
        _define_dynamic_accessor(method_str.chomp("="))
        instance_variable_set("@#{method_str.chomp('=')}", args.first)
      elsif _valid_attribute_name?(method_str) && instance_variable_defined?("@#{method_str}")
        instance_variable_get("@#{method_str}")
      elsif !method_str.end_with?("?")
        _define_dynamic_accessor(method_str)
        nil
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      method_str.end_with?("=") ||
        (_valid_attribute_name?(method_str) && instance_variable_defined?("@#{method_str}")) ||
        (!method_str.end_with?("?") && _valid_attribute_name?(method_str)) ||
        super
    end

    private

    def _define_dynamic_accessor(key)
      return if self.class.method_defined?("#{key}=")
      self.class.send(:attr_accessor, key)
    end

    def _valid_attribute_name?(name)
      /\A[a-zA-Z_]\w*\z/.match?(name)
    end
  end
end
