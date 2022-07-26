module GraphitiGql
  class ExecutionController < GraphitiGql.config.application_controller
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
