module GraphitiGql
  class Schema
    module Fields
      class ToOne
        def initialize(sideload, sideload_type)
          @sideload = sideload
          @sideload_type = sideload_type
        end

        def apply(type)
          field = type.field @sideload.name,
            @sideload_type,
            null: true,
            extras: [:lookahead]
          _sideload = @sideload
          type.define_method(@sideload.name) do |**arguments|
            Util.is_readable_sideload!(_sideload)

            if _sideload.type == :has_one
              id = object.send(_sideload.primary_key)
              params = { filter: { _sideload.foreign_key => { eq: id } } }

              resource = Schema.registry.get(@sideload.resource.class)[:resource]
              return resource.all(params).data[0]
            end

            lookahead = arguments[:lookahead]
            id = object.send(_sideload.foreign_key)
            if id.nil?
              Loaders::BelongsTo.for(_sideload, {}).load(nil)
            else
              params = Util.params_from_args(arguments)

              if _sideload.type == :polymorphic_belongs_to
                id = { id: id, type: object.send(_sideload.grouper.field_name) }
              end

              selections = lookahead.selections.map(&:name).sort
              if selections == [:id] || selections == [:__typename, :id]
                params[:simpleid] = true
              end
              Loaders::BelongsTo.for(_sideload, params).load(id)
            end
          end
        end
      end
    end
  end
end