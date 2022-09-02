module GraphitiGql
  class Schema
    class Query
      def initialize(resources, existing_query: nil)
        @resources = resources
        @query_class = Class.new(existing_query || Schema.base_object)
        @query_class.graphql_name "Query"
      end

      def build
        @resources.each { |resource| ResourceType.new(resource).build }
        define_entrypoints
        add_value_objects
        add_relationships
        @query_class
      end

      private

      def registry
        Registry.instance
      end

      def define_entrypoints
        registry.resource_types.each do |registered|
          if registered[:resource].graphql_entrypoint
            Fields::Index.new(registered).apply(@query_class)
            Fields::Show.new(registered).apply(@query_class)
          end
        end
      end

      def add_relationships
        registry.resource_types.each do |registered|
          resource, type = registered[:resource], registered[:type]
          ResourceType.add_relationships(resource, type)
        end
      end

      def add_value_objects
        registry.resource_types(value_objects: false).each do |registered|
          resource, type = registered[:resource], registered[:type]
          ResourceType.add_value_objects(resource, type)
        end
      end
    end
  end
end