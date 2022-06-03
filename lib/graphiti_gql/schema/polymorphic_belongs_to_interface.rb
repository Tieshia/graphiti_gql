module GraphitiGql
  class Schema
    class PolymorphicBelongsToInterface
      def initialize(resource, sideload)
        @resource = resource
        @sideload = sideload
      end

      def build
        return registry[name][:type] if registry[name]

        klass = Module.new
        klass.send :include, ResourceType::BaseInterface
        klass.field :id, String, null: false
        klass.field :_type, String, null: false
        klass.graphql_name(name)
        @sideload.children.values.each do |child|
          registry.get(child.resource.class)[:type].implements(klass)
        end
        registry[name] = { type: klass }
        registry[name]
      end

      private

      def registry
        Registry.instance
      end

      def name
        "#{registry.key_for(@resource)}__#{@sideload.name}"
      end
    end
  end
end