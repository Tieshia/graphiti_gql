# These should be in Graphiti itself, but can't do it quite yet b/c GQL coupling.
# Ideally we eventually rip out the parts of Graphiti we need and roll this into
# that effort.
module GraphitiGql
  module ResourceExtras
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :graphql_name
      end
    end

    class_methods do
      def attribute(*args)
        super(*args).tap do
          opts = args.extract_options!
          att = config[:attributes][args[0]]
          att[:deprecation_reason] = opts[:deprecation_reason]
          att[:null] = opts.key?(:null) ? opts[:null] : args[0] != :id
          att[:name] = args.first # for easier lookup
        end
      end
    end
  end
  Graphiti::Resource.send(:include, ResourceExtras)

  module FilterExtras
    def filter_param
      default_filter = resource.default_filter if resource.respond_to?(:default_filter)
      default_filter ||= {}
      default_filter.merge(super)
    end

    # Only for alias, tiny diff
    def filter_via_adapter(filter, operator, value)
      type_name = ::Graphiti::Types.name_for(filter.values.first[:type])
      method = :"filter_#{type_name}_#{operator}"
      name = filter.keys.first
      name = resource.all_attributes[name][:alias] || name

      if resource.adapter.respond_to?(method)
        resource.adapter.send(method, @scope, name, value)
      else
        raise ::Graphiti::Errors::AdapterNotImplemented.new \
          resource.adapter, name, method
      end
    end
  end
  Graphiti::Scoping::Filter.send(:prepend, FilterExtras)

  module SortAliasExtras
    def each_sort
      sort_param.each do |sort_hash|
        name = sort_hash.keys.first
        name = resource.all_attributes[name][:alias] || name
        direction = sort_hash.values.first
        yield name, direction
      end
    end
  end
  Graphiti::Scoping::Sort.send(:prepend, SortAliasExtras)

  module StatsExtras
    def calculate_stat(name, function)
      config = @resource.all_attributes[name] || {}
      name = config[:alias] || name
      super(name, function)
    end
  end
  Graphiti::Stats::Payload.send(:prepend, StatsExtras)

  # ==================================================
  # Below is all to support pagination argument 'last'
  # ==================================================
  module SortExtras
    def sort_param
      param = super
      if query_hash[:reverse]
        param = [{ id: :asc }] if param == []
        param = param.map do |p|
          {}.tap do |hash|
            dir = p[p.keys.first]
            dir = dir == :asc ? :desc : :asc
            hash[p.keys.first] = dir
          end
        end
      end
      param
    end
  end
  Graphiti::Scoping::Sort.send(:prepend, SortExtras)
  module QueryExtras
    def hash
      hash = super
      hash[:reverse] = true if @params[:reverse]
      hash
    end
  end
  Graphiti::Query.send(:prepend, QueryExtras)
  module ScopeExtras
    def resolve(*args)
      results = super
      results.reverse! if @query.hash[:reverse]
      results
    end
  end
  Graphiti::Scope.send(:prepend, ScopeExtras)
end