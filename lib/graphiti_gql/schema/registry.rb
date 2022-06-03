module GraphitiGql
  class Schema
    class Registry
      include Singleton

      def initialize
        clear
      end

      def get(object, interface: true)
        @data[key_for(object, interface: interface)]
      end

      def set(resource, type, interface: true)
        @data[key_for(resource, interface: interface)] = { resource: resource, type: type, interface: interface }
      end

      def key_for(object, interface: true)
        if object.ancestors.include?(Graphiti::Resource) 
          key = key_for_resource(object)
          if object.polymorphic?
            if !object.polymorphic_child? && interface
              key = "I#{key}"
            end
          end
          key
        else
          raise 'unknown object!'
        end
      end

      def clear
        @data = {}
      end

      def []=(key, value)
        @data[key] = value
      end

      def [](key)
        @data[key]
      end

      def key?(key)
        @data.key?(key)
      end

      def values
        @data.values
      end

      # When polymorphic parent, returns the Interface not the Class
      def resource_types
        values
          .select { |v| v.key?(:resource) && !v[:interface] }
          .map { |registered| get(registered[:resource]) }
      end

      private

      def key_for_resource(resource)
        resource.graphql_name ||
          resource.name.gsub('Resource', '').gsub('::', '')
      end
    end
  end
end