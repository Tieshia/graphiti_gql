module GraphitiGql
  class Schema
    module Fields
      class ToMany
        def initialize(sideload, sideload_type)
          @sideload = sideload
          @sideload_type = sideload_type
        end

        def apply(type)
          field = type.field @sideload.name,
            @sideload_type.connection_type,
            null: false,
            connection: false,
            extensions: [RelayConnectionExtension],
            extras: [:lookahead]
          ListArguments.new(@sideload.resource.class, @sideload).apply(field)
          _sideload = @sideload
          type.define_method(@sideload.name) do |**arguments|
            Util.is_readable_sideload!(_sideload)
            params = Util.params_from_args(arguments)
            pk = object.send(_sideload.primary_key)
            id = if _sideload.polymorphic_as
              hash = {}
              hash[_sideload.foreign_key] = pk
              hash[:"#{_sideload.polymorphic_as}_type"] = object.class.name
              id = hash
            else
              id = pk
            end
            Loaders::Many.factory(_sideload, params).load(id)
          end
        end
      end
    end
  end
end