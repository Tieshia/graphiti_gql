module GraphitiGql
  class Schema
    class ResourceType
      module BaseInterface
        include GraphQL::Schema::Interface

        definition_methods do
          # Optional: if this method is defined, it overrides `Schema.resolve_type`
          def resolve_type(object, context)
            return object.type if object.is_a?(Loaders::FakeRecord)
            resource = object.instance_variable_get(:@__graphiti_resource)
            Registry.instance.get(resource.class)[:type]
          end
        end
      end

      def initialize(resource, implements: nil)
        @resource = resource
        @implements = implements
      end

      def build
        return registry.get(@resource)[:type] if registry.get(@resource)
        type = build_base_type
        registry_name = registry.key_for(@resource, interface: poly_parent?)
        type.connection_type_class(build_connection_class)
        type.graphql_name(registry_name)
        type.implements(@implements) if @implements
        add_fields(type, @resource)
        registry.set(@resource, type, interface: poly_parent?)
        process_polymorphic_parent(type) if poly_parent?
        type
      end

      private

      def process_polymorphic_parent(type)
        # Define the actual class that implements the interface
        registry.set(@resource, type, interface: false)
        @resource.children.each do |child|
          if (registered = registry.get(child))
            registered[:type].implements(type)
          else
            self.class.new(child, implements: type).build
          end
        end
      end

      def poly_parent?
        @resource.polymorphic? && !@resource.polymorphic_child?
      end

      def build_base_type
        klass = nil
        if poly_parent?
          type_name = "I#{name}"
          klass = Module.new
          klass.send(:include, BaseInterface)
          ctx = nil
          klass.definition_methods { ctx = self }
          ctx.define_method :resolve_type do |object, context|
            resource = object.instance_variable_get(:@__graphiti_resource)
            registry_name = Registry.instance.key_for(resource.class)
            if resource.polymorphic?
              resource = resource.class.resource_for_model(object)
              registry_name = Registry.instance.key_for(resource)
            end
            Registry.instance[registry_name][:type]
          end
        else
          klass = Class.new(GraphQL::Schema::Object)
        end

        klass
      end

      def registry
        Registry.instance
      end

      def name
        registry.key_for(@resource)
      end
  
      def add_fields(type, resource)
        resource.attributes.each_pair do |name, config|
          if config[:readable]
            Fields::Attribute.new(name, config).apply(type)
          end
        end
      end

      def build_connection_class
        klass = Class.new(GraphQL::Types::Relay::BaseConnection)
        Fields::Stats.new(@resource).apply(klass)
        klass
      end
    end
  end
end