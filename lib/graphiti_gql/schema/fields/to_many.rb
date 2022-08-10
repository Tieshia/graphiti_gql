module GraphitiGql
  class Schema
    module Fields
      class ToMany
        def initialize(sideload, sideload_type)
          @sideload = sideload
          @sideload_type = sideload_type
          @connection_type = find_or_build_connection
        end

        def apply(type)
          opts = {
            null: has_one?,
            connection: false,
            extras: [:lookahead]
          }
          opts[:extensions] = [RelayConnectionExtension] unless has_one?
          field_type = has_one? ? @sideload_type : @connection_type
          field = type.field @sideload.name,
            field_type,
            **opts
          ListArguments.new(@sideload.resource.class, @sideload).apply(field)
          _sideload = @sideload
          type.define_method(@sideload.name) do |**arguments|
            Util.is_readable_sideload!(_sideload)
            params = Util.params_from_args(arguments)
            Loaders::Many.factory(_sideload, params).load(object)
          end
        end

        private

        def has_one?
          @sideload.type == :has_one
        end

        def customized_edge?
          @sideload.type == :many_to_many && @sideload.edge_resource
        end

        def find_or_build_connection
          registered_parent = Schema.registry.get(@sideload.parent_resource.class)
          parent_name = registered_parent[:type].graphql_name
          name = "#{parent_name}To#{@sideload_type.graphql_name}Connection"
          return Schema.registry[name][:type] if Schema.registry[name]

          if customized_edge?
            prior = @sideload_type.connection_type
            klass = Class.new(prior)
            klass.graphql_name(name)
            edge_type_class = build_edge_type_class(@sideload_type)
            edge_type_class.node_type(prior.node_type)
            klass.edge_type(edge_type_class)
            Schema.registry[name] = { type: klass }
            klass
          else
            @sideload_type.connection_type
          end
        end

        def build_edge_type_class(sideload_type)
          klass = build_friendly_graphql_edge_type_class \
            sideload_type.edge_type_class
          name = edge_type_class_name(sideload_type)
          klass.define_method(:graphql_name) { name }
          klass.graphql_name(name)
          edge_resource = @sideload.edge_resource
          ResourceType.add_fields(klass, edge_resource, id: false)
          ResourceType.add_relationships(edge_resource, klass)
          klass
        end

        # Normally we reference 'object', but edges work differently
        # This makes 'object' work everywhere
        # Needed when evaluating fields/relationships for consistent interface
        def build_friendly_graphql_edge_type_class(superklass)
          klass = Class.new(superklass) do
            alias :original_object :object
            def object
              return @_object if @_object # avoid conflict

              node = original_object.node # the 'parent' record we joined with
              edge_attrs = node.attributes.select { |k,v| k.to_s.starts_with?('_edge') }
              edge_attrs.transform_keys! { |k| k.to_s.gsub('_edge_', '') }
              edge_model = model.new(edge_attrs)
              edge_model.instance_variable_set(:@__graphiti_resource, resource)
              @_object = edge_model
              @_object
            end

            def cursor
              original_object.cursor
            end

            def node
              original_object.node
            end
          end

          # used in #object
          thru = @sideload.foreign_key.keys.first
          reflection = @sideload.parent_resource.model.reflect_on_association(thru)
          thru_model = reflection.klass
          edge_resource = @sideload.edge_resource.new
          klass.define_method(:model) { thru_model }
          klass.define_method(:resource) { edge_resource }

          klass
        end

        def edge_type_class_name(sideload_type)
          registered_parent = Schema.registry.get \
            @sideload.parent_resource.class
          parent_name = registered_parent[:type].graphql_name
          "#{parent_name}To#{sideload_type.graphql_name}Edge"
        end
      end
    end
  end
end