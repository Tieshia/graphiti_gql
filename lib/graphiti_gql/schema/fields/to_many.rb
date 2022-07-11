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
          @sideload.type == :many_to_many && @sideload.class.edge_resource
        end

        def find_or_build_connection
          if customized_edge?
            prior = @sideload_type.connection_type
            klass = Class.new(prior)
            registered_parent = Schema.registry.get(@sideload.parent_resource.class)
            parent_name = registered_parent[:type].graphql_name
            name = "#{parent_name}To#{@sideload_type.graphql_name}Connection"
            klass.graphql_name(name)
            edge_type_class = build_edge_type_class(@sideload_type)
            edge_type_class.node_type(prior.node_type)
            klass.edge_type(edge_type_class)
            klass
          else
            @sideload_type.connection_type
          end
        end

        def build_edge_type_class(sideload_type)
          prior_edge_type_class = sideload_type.edge_type_class
          edge_type_class = Class.new(prior_edge_type_class)
          edge_resource = @sideload.class.edge_resource
          edge_resource.attributes.each_pair do |name, config|
            next if name == :id
            Schema::Fields::Attribute.new(name, config, @sideload).apply(edge_type_class)
          end
          registered_parent = Schema.registry.get(@sideload.parent_resource.class)
          parent_name = registered_parent[:type].graphql_name
          edge_type_class_name = "#{parent_name}To#{sideload_type.graphql_name}Edge"
          edge_type_class.define_method :graphql_name do
            edge_type_class_name
          end
          edge_type_class.graphql_name(edge_type_class_name)
          edge_type_class
        end
      end
    end
  end
end