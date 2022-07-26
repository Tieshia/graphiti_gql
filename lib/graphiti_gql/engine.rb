module GraphitiGql
  class Engine < ::Rails::Engine
    isolate_namespace GraphitiGql

    # TODO improvable?
    config.after_initialize do
    # initializer "graphiti_gql.generate_schema" do
      Dir.glob("#{Rails.root}/app/resources/**/*").each { |f| require(f) }
      GraphitiGql.schema!
    end

    module ControllerContext
      def graphql_context
        ctx = { controller: self }
        ctx[:current_user] = current_user if respond_to?(:current_user)
        ctx
      end
    end

    initializer "graphiti_gql.define_controller" do
      app_controller = GraphitiGql.config.application_controller || ::ApplicationController
      app_controller.send(:include, ControllerContext)

      # rubocop:disable Lint/ConstantDefinitionInBlock(Standard)
      class GraphitiGql::ExecutionController < app_controller
        def execute
          params = request.params # avoid strong_parameters
          variables = params[:variables] || {}
          result = GraphitiGql.run params[:query],
            params[:variables],
            graphql_context
          render json: result
        end

        private

        def default_context
          defined?(:current_user)
        end
      end
    end
  end
end