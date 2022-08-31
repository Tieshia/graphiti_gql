module GraphitiGql
  class Schema
    module Fields
      class Show
        def initialize(registered)
          @registered = registered
        end

        def apply(query)
          field = query.field name,
            @registered[:type],
            null: true,
            extras: [:lookahead]
          unless @registered[:resource].singular
            field.argument(:id, GraphQL::Types::ID, required: true)
          end
          _registered = @registered
          query.define_method name do |**arguments|
            params = Util.params_from_args(arguments)
            _registered[:resource].all(params).data[0]
          end
        end

        private

        def name
          @registered[:resource]
            .graphql_entrypoint.to_s
            .underscore
            .singularize.to_sym
        end
      end
    end
  end
end