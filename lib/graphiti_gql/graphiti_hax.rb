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

    def selections
      return @selections if @selections
      lookahead = context[:current_arguments]
        .keyword_arguments[:lookahead]
      nodes = lookahead.selection(:nodes)
      if !nodes.selected?
        nodes = lookahead
          .selection(:edges)
          .selection(:node)
      end

      if !nodes.selected?
        nodes = lookahead
      end

      @selections = nodes
        .selections
        .map(&:name).map { |name| name.to_s.underscore.to_sym }
      @selections
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

    def each_filter
      super do |filter, operator, value|
        unless filter.values[0][:allow_nil]
          has_nil = value.nil? || value.is_a?(Array) && value.any?(&:nil?)
          raise Errors::NullFilter.new(filter.keys.first) if has_nil
        end
        yield filter, operator, value
      end
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

  module PaginateExtras
    def apply
      if query_hash[:reverse] && (before_cursor || after_cursor)
        raise ::GraphitiGql::Errors::UnsupportedLast
      end
      super
    end

    def offset
      offset = 0

      if (value = page_param[:offset])
        offset = value.to_i
      end

      if before_cursor&.key?(:offset)
        if page_param.key?(:number)
          raise Errors::UnsupportedBeforeCursor
        end

        offset = before_cursor[:offset] - (size * number) - 1
        offset = 0 if offset.negative?
      end

      if after_cursor&.key?(:offset)
        offset = after_cursor[:offset]
      end

      offset
    end

    # TODO memoize
    def size
      size = super
      if before_cursor && after_cursor
        diff = before_cursor[:offset] - after_cursor[:offset] - 1
        size = [size, diff].min
      elsif before_cursor
        comparator = query_hash[:reverse] ? :>= : :<=
        if before_cursor[:offset].send(comparator, size)
          diff = before_cursor[:offset] - size
          size = [size, diff].min
          size = 1 if size.zero?
        end
      end
      size
    end
  end
  Graphiti::Scoping::Paginate.send(:prepend, PaginateExtras)

  module ManyToManyExtras
    extend ActiveSupport::Concern

    class_methods do
      attr_accessor :edge_resource

      def attribute(*args, &blk)
        @edge_resource = Class.new(Graphiti::Resource) do
          def self.abstract_class?
            true
          end
        end
        @edge_resource.attribute(*args, &blk)
      end
    end
  end
  Graphiti::Sideload::ManyToMany.send(:include, ManyToManyExtras)

  module StatsExtras
    def calculate_stat(name, function)
      config = @resource.all_attributes[name] || {}
      name = config[:alias] || name
      super(name, function)
    end
  end
  Graphiti::Stats::Payload.send(:prepend, StatsExtras)

  Graphiti::Types[:big_integer] = Graphiti::Types[:integer].dup
  Graphiti::Types[:big_integer][:graphql_type] = ::GraphQL::Types::BigInt

  ######## support precise_datetime ###########
  #############################################
  definition = Dry::Types::Nominal.new(String)
  _out = definition.constructor do |input|
    input.utc.round(10).iso8601(6)
  end

  _in = definition.constructor do |input|
    Time.zone.parse(input)
  end

  # Register it with Graphiti
  Graphiti::Types[:precise_datetime] = {
    params: _in,
    read: _out,
    write: _in,
    kind: 'scalar',
    canonical_name: :precise_datetime,
    description: 'Datetime with milliseconds'
  }

  module ActiveRecordAdapterExtras
    extend ActiveSupport::Concern

    included do
      alias_method :filter_precise_datetime_lt, :filter_lt
      alias_method :filter_precise_datetime_lte, :filter_lte
      alias_method :filter_precise_datetime_gt, :filter_gt
      alias_method :filter_precise_datetime_gte, :filter_gte
      alias_method :filter_precise_datetime_eq, :filter_eq
      alias_method :filter_precise_datetime_not_eq, :filter_not_eq
    end
  end
  if defined?(Graphiti::Adapters::ActiveRecord)
    Graphiti::Adapters::ActiveRecord.send(:include, ActiveRecordAdapterExtras)
  end

  Graphiti::Adapters::Abstract.class_eval do
    class << self
      alias :old_default_operators :default_operators
      def default_operators
        old_default_operators.merge(precise_datetime: numerical_operators)
      end
    end
  end
  ########## end support precise_datetime ############

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

  module ActiveRecordManyToManyExtras
    # flipping .includes to .joins
    def belongs_to_many_filter(scope, value)
      scope
        .joins(through_relationship_name)
        .where(belongs_to_many_clause(value, type))
    end
  end
  if defined?(ActiveRecord)
    ::Graphiti::Adapters::ActiveRecord::ManyToManySideload
      .send(:prepend, ActiveRecordManyToManyExtras)
  end
end