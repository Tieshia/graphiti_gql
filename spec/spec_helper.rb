require "bundler/setup"
require "pry"
require "graphql"
require "graphiti"
require "graphiti_gql"

# TODO: jsonapi specific
Graphiti::Resource.validate_endpoints = false
Graphiti::Resource.autolink = false

require "fixtures"

# Preserve for tests
Graphiti.setup!
original_resources = Graphiti.resources

def run(query, variables = {}, context = {}, full: false)
  raw = GraphitiGql.run(query, variables, context).deep_symbolize_keys
  raw.key?(:errors) ? raw : raw[:data]
end

def schema!
  reload_resources
  GraphitiGql.schema!
end

# so tests can create/update resource classes
def reload_resources
  _resources ||= Graphiti.resources.reject(&:abstract_class?)
  _resources.reject! { |r| r.name.nil? }
  collected = []
  _resources.reverse_each do |resource|
    already_collected = collected.find { |c| c.name == resource.name }
    collected << resource unless already_collected
  end
  _resources = collected
  Graphiti.instance_variable_set(:@resources, _resources)
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    GraphitiGql.config.error_handling = false
    schema!
  end

  config.after do
    PORO::DB.clear
    GraphitiGql.instance_variable_set(:@config, nil)

    collected = []
    original_resources.each do |resource|
      collected << resource
    end
    Graphiti.instance_variable_set(:@resources, collected)
  end
end
