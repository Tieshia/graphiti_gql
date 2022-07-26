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
        each_relationship do |type, sideload_type, sideload|
          if [:has_many, :many_to_many, :has_one].include?(sideload.type)
            Fields::ToMany.new(sideload, sideload_type).apply(type)
          else
            Fields::ToOne.new(sideload, sideload_type).apply(type)
          end
        end
      end

      def each_relationship
        registry.resource_types.each do |registered|
          registered[:resource].sideloads.each do |name, sl|
            next unless sl.readable?

            registered_sl = if sl.type == :polymorphic_belongs_to
              PolymorphicBelongsToInterface
                .new(registered[:resource], sl)
                .build
            else
              registry.get(sl.resource.class)
            end

            yield registered[:type], registered_sl[:type], sl
          end
        end
      end
    end
  end
end