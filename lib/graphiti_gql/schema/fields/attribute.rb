module GraphitiGql
  class Schema
    module Fields
      class Attribute
        # If sideload is present, we're applying m2m metadata to an edge
        def initialize(name, config, sideload = nil)
          @config = config
          @name = name
          @alias = config[:alias]
          @sideload = sideload # is_edge: true
        end

        def apply(type)
          is_nullable = !!@config[:null]
          _config = @config
          _name = @name
          _alias = @alias 
          _sideload = @sideload
          opts = @config.slice(:null, :deprecation_reason)
          type.field(_name, field_type, **opts)
          type.define_method _name do
            if (readable = _config[:readable]).is_a?(Symbol)
              obj = object
              obj = object.node if _sideload
              resource = obj.instance_variable_get(:@__graphiti_resource)
              unless resource.send(readable)
                path = Graphiti.context[:object][:current_path].join(".")
                raise Errors::UnauthorizedField.new(path)
              end
            end

            edge_attrs = nil
            if _sideload
              edge_attrs = object.node.attributes
                .select { |k, v| k.to_s.starts_with?("_edge_") }
              edge_attrs.transform_keys! { |k| k.to_s.gsub("_edge_", "").to_sym }
            end

            value = if _config[:proc]
              if _sideload
                instance_exec(edge_attrs, object.node, &_config[:proc])
              else
                instance_eval(&_config[:proc])
              end
            else
              if _sideload
                edge_attrs[_alias || _name]
              else
                object.send(_alias || _name)
              end
            end
            return if value.nil?
            Graphiti::Types[_config[:type]][:read].call(value)
          end
        end

        private

        def field_type
          field_type = Graphiti::Types[@config[:type]][:graphql_type]
          if !field_type
            canonical_graphiti_type = Graphiti::Types.name_for(@config[:type])
            field_type = GQL_TYPE_MAP[canonical_graphiti_type.to_sym]
            field_type = String if @name == :id
          end
          field_type = [field_type] if @config[:type].to_s.starts_with?("array_of")
          field_type
        end
      end
    end
  end
end