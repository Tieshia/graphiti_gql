module GraphitiGql
  class Schema
    module Fields
      class Attribute
        # If sideload is present, we're applying m2m metadata to an edge
        def initialize(resource, name, config)
          @resource = resource
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
              obj = object
              resource = obj.instance_variable_get(:@__graphiti_resource)
              unless resource.send(readable)
                path = Graphiti.context[:object][:current_path].join(".")
                raise Errors::UnauthorizedField.new(path)
              end
            end

            value = if _config[:proc]
              instance_eval(&_config[:proc])
            else
              if object.is_a?(Hash)
                object[_name] || object[_name.to_s]
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
          if [:integer_enum, :string_enum].any? { |t| @config[:type] == t }
            return find_or_create_enum_type
          else
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

        def find_or_create_enum_type
          resource_type_name = Schema.registry.key_for(@resource, interface: false)
          enum_type_name = "#{resource_type_name}_#{@name}"
          if (registered = Schema.registry[enum_type_name])
            registered[:type]
          else
            klass = Class.new(GraphQL::Schema::Enum)
            klass.graphql_name(enum_type_name)
            @config[:allow].each do |allowed|
              klass.value(allowed)
            end
            Schema.registry[enum_type_name] = { type: klass }
            klass
          end
        end
      end
    end
  end
end