module GraphitiGql
  class Engine < ::Rails::Engine
    isolate_namespace GraphitiGql

    # TODO improvable?
    config.to_prepare do
    # initializer "graphiti_gql.generate_schema" do
      Dir.glob("#{Rails.root}/app/resources/**/*").each { |f| require(f) }
      GraphitiGql.schema!
    end
  end
end
