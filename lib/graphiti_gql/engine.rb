module GraphitiGql
  class Engine < ::Rails::Engine
    isolate_namespace GraphitiGql

    # TODO improvable?
    config.after_initialize do
    # initializer "graphiti_gql.generate_schema" do
      Dir.glob("#{Rails.root}/app/resources/**/*").each { |f| require(f) }
      GraphitiGql.schema!
    end

    initializer "graphiti_gql.define_controller" do
      app_controller = GraphitiGql.config.application_controller || ::ApplicationController

      # rubocop:disable Lint/ConstantDefinitionInBlock(Standard)
      class GraphitiGql::ExecutionController < app_controller
        def execute
          params = request.params # avoid strong_parameters
          variables = params[:variables] || {}
          ctx = respond_to?(:graphql_context) ? graphql_context : {}
          result = GraphitiGql.run params[:query],
            params[:variables],
            ctx
          render json: result
        end
      end
    end
  end
end