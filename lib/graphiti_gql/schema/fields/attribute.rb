module GraphitiGql
  class Schema
    module Fields
      class Attribute
        def initialize(name, config)
          @config = config
          @name = name
          @alias = config[:alias]
        end

        def apply(type)
          is_nullable = !!@config[:null]
          _config = @config
          _name = @name
          _alias = @alias 
          opts = @config.slice(:null, :deprecation_reason)
          type.field(_name, field_type, **opts)
          type.define_method _name do
            if (readable = _config[:readable]).is_a?(Symbol)
              resource = object.instance_variable_get(:@__graphiti_resource)
              unless resource.send(readable)
                path = Graphiti.context[:object][:current_path].join(".")
                raise Errors::UnauthorizedField.new(path)
              end
            end
            value = if _config[:proc]
              instance_eval(&_config[:proc])
            else
              object.send(_alias || _name)
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