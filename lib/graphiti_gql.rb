require "active_support/core_ext/object/json"
require "graphql"
require 'graphql/batch'
require 'active_model'
require "graphiti_gql/graphiti_hax"
require "graphiti_gql/version"
require "graphiti_gql/errors"
require "graphiti_gql/loaders/many"
require "graphiti_gql/loaders/has_many"
require "graphiti_gql/loaders/many_to_many"
require "graphiti_gql/loaders/polymorphic_has_many"
require "graphiti_gql/loaders/belongs_to"
require "graphiti_gql/loaders/has_one"
require "graphiti_gql/response_shim"
require "graphiti_gql/schema"
require "graphiti_gql/schema/connection"
require "graphiti_gql/schema/registry"
require "graphiti_gql/schema/util"
require "graphiti_gql/schema/query"
require "graphiti_gql/schema/resource_type"
require "graphiti_gql/schema/polymorphic_belongs_to_interface"
require "graphiti_gql/schema/list_arguments"
require "graphiti_gql/schema/fields/show"
require "graphiti_gql/schema/fields/index"
require "graphiti_gql/schema/fields/to_many"
require "graphiti_gql/schema/fields/to_one"
require "graphiti_gql/schema/fields/attribute"
require "graphiti_gql/schema/fields/stats"
require "graphiti_gql/active_resource"
require "graphiti_gql/exception_handler"
require "graphiti_gql/log_subscriber"
require "graphiti_gql/engine" if defined?(Rails)

module GraphitiGql
  class Error < StandardError; end

  class Configuration
    attr_accessor :exception_handler, :error_handling, :logging

    def exception_handler
      @exception_handler ||= ExceptionHandler
    end

    def error_handling
      @error_handling != false
    end

    def log
      @log ||= !ENV['GRAPHITI_LOG_LEVEL'].nil?
    end
  end

  def self.schema!
    Schema::Registry.instance.clear
    resources ||= Graphiti.resources.reject(&:abstract_class?)
    @schema = Schema.new(resources).generate
  end

  def self.schema
    @schema
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end

  def self.entrypoint?(resource)
    !!resource.graphql_entrypoint
  end

  def self.run(query_string, variables = {}, context = {})
    if context.empty? && Graphiti.context[:object]
      context = Graphiti.context[:object]
    end
    Graphiti.with_context(context) do
      payload = {
        query: query_string,
        variables: variables,
        context: context
      }
      Graphiti.broadcast("schema.before_execute", payload)
      Graphiti.broadcast("schema.execute", payload) do
        result = schema.execute query_string,
          variables: variables,
          context: context
        result_hash = result.to_h
        payload[:result] = result_hash
        result_hash
      end
    end
  end
end
