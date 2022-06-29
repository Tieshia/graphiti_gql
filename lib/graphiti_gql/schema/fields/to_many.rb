module GraphitiGql
  class Schema
    module Fields
      class ToMany
        def initialize(sideload, sideload_type)
          @sideload = sideload
          @sideload_type = if customized_edge?
              build_customized_edge_type(sideload_type)
            else
              sideload_type
            end
        end

        def apply(type)
          opts = {
            null: has_one?,
            connection: false,
            extras: [:lookahead]
          }
          opts[:extensions] = [RelayConnectionExtension] unless has_one?
          field_type = has_one? ? @sideload_type : @sideload_type.connection_type
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

        def build_customized_edge_type(sideload_type)
          # build the edge class
          prior_edge_class = sideload_type.edge_type_class
          edge_class = Class.new(prior_edge_class)
          edge_resource = @sideload.class.edge_resource
          edge_resource.attributes.each_pair do |name, config|
            next if name == :id
            Schema::Fields::Attribute.new(name, config, @sideload).apply(edge_class)
          end
          registered_parent = Schema.registry.get(@sideload.parent_resource.class)
          parent_name = registered_parent[:type].graphql_name
          edge_class.define_method :graphql_name do
            "#{parent_name}To#{sideload_type.graphql_name}Edge"
          end

          # build the sideload type with new edge class applied
          klass = Class.new(sideload_type)
          klass.edge_type_class(edge_class)
          klass
        end
      end
    end
  end
end