module GraphitiGql
  class Schema
    module Fields
      class Index
        def initialize(registered)
          @registered = registered
        end

        def apply(query)
          resource = @registered[:resource]
          field = query.field resource.graphql_entrypoint,
            @registered[:type].connection_type,
            null: false,
            connection: false,
            extensions: [RelayConnectionExtension],
            extras: [:lookahead]
          ListArguments.new(resource).apply(field)
          query.define_method name do |**arguments|
            params = Util.params_from_args(arguments)
            proxy = resource.all(params)
            ResponseShim.new(proxy.data, proxy)
          end
        end

        private

        def name
          @registered[:resource].graphql_entrypoint
        end
      end
    end
  end
end