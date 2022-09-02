module GraphitiGql
  class Schema
    class ResourceType
      module BaseInterface
        include GraphQL::Schema::Interface

        definition_methods do
          # Optional: if this method is defined, it overrides `Schema.resolve_type`
          def resolve_type(object, _context)
            return object.type if object.is_a?(Loaders::FakeRecord)

            resource = object.instance_variable_get(:@__graphiti_resource)
            Registry.instance.get(resource.class)[:type]
          end
        end
      end

      def self.add_fields(type, resource, id: true) # id: false for edges
        resource.attributes.each_pair do |name, config|
          next if name == :id && id == false

          Fields::Attribute.new(resource, name, config).apply(type) if config[:readable]
        end
      end

      def self.add_value_objects(resource, type)
        resource.config[:value_objects].each_pair do |name, vo_association|
          vo_resource_class = vo_association.resource_class
          value_object_type = Schema.registry.get(vo_resource_class)[:type]
          value_object_type = [value_object_type] if vo_association.array?

          _array = vo_association.array?
          opts = { null: vo_association.null }
          opts[:deprecation_reason] = vo_association.deprecation_reason if vo_association.deprecation_reason
          type.field name, value_object_type, **opts
          type.define_method name do
            if (method_name = vo_association.readable) && !vo_association.parent_resource_class.new.send(method_name)
              raise ::Graphiti::Errors::UnreadableAttribute
                .new(vo_association.parent_resource_class, name)
            end

            result = vo_resource_class.all({ parent: object }).to_a
            default_behavior = result == [object]
            result = result.first unless _array
            if default_behavior
              method_name = vo_association.alias.presence || name
              result = object.send(method_name)
              raise Graphiti::Errors::InvalidValueObject.new(resource, name, result) if _array && !result.is_a?(Array)
            end
            # For polymorphic value objects
            if result.is_a?(Array)
              result.each { |r| r.instance_variable_set(:@__parent, object) }
            else
              result.instance_variable_set(:@__parent, object) if result
            end
            result
          end
        end
      end

      def self.add_relationships(resource, type)
        resource.sideloads.each do |_name, sideload|
          next unless sideload.readable?

          registered_sl = if sideload.type == :polymorphic_belongs_to
                            PolymorphicBelongsToInterface
                              .new(resource, sideload)
                              .build
                          else
                            Schema.registry.get(sideload.resource.class)
                          end
          sideload_type = registered_sl[:type]

          if %i[has_many many_to_many has_one].include?(sideload.type)
            Fields::ToMany.new(sideload, sideload_type).apply(type)
          else
            Fields::ToOne.new(sideload, sideload_type).apply(type)
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

      def process_polymorphic_parent(interface_type)
        registry_name = registry.key_for(@resource, interface: false)
        type = Class.new(Schema.base_object)
        type.graphql_name(registry_name)
        type.implements(interface_type)

        # Define the actual class that implements the interface
        registry.set(@resource, type, interface: false)
        @resource.children.each do |child|
          registry.get(child)
          if (registered = registry.get(child))
            registered[:type].implements(interface_type)
          else
            self.class.new(child, implements: interface_type).build
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
          _resource = @resource
          ctx.define_method :resolve_type do |object, _context|
            registry_name = Registry.instance.key_for(_resource)
            if _resource.polymorphic?
              parent = object.instance_variable_get(:@__parent)
              # pass parent for polymorphic value objects
              _resource = _resource.resource_for_model(parent || object)
              registry_name = Registry.instance.key_for(_resource)
            end
            Registry.instance[registry_name][:type]
          end
        else
          klass = Class.new(Schema.base_object)
        end

        if @resource.value_object?
          klass.define_method :parent do
            object.instance_variable_get(:@__parent)
          end
        end

        klass.define_method :resource do
          return @resource if @resource

          resource = object.instance_variable_get(:@__graphiti_resource)
          resource_class = resource.class
          if resource_class.polymorphic? && !resource_class.polymorphic_child?
            resource_class = resource_class.resource_for_model(object)
          end
          @resource = resource_class
          resource_class
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
        self.class.add_fields(type, resource)
      end

      def build_connection_class
        klass = Class.new(GraphQL::Types::Relay::BaseConnection)
        Fields::Stats.new(@resource).apply(klass)
        klass
      end
    end
  end
end
