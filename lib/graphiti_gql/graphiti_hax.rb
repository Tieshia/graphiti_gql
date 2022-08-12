# These should be in Graphiti itself, but can't do it quite yet b/c GQL coupling.
# Ideally we eventually rip out the parts of Graphiti we need and roll this into
# that effort.
module GraphitiGql
  module RunnerExtras
    def jsonapi_resource
      @jsonapi_resource ||= begin
        r = @resource_class.new
        r.instance_variable_set(:@params, @params)
        r
      end
    end
  end
  Graphiti::Runner.send(:prepend, RunnerExtras)

  module ResourceExtras
    extend ActiveSupport::Concern

    prepended do
      extend ActiveModel::Callbacks
      define_model_callbacks :query

      class << self
        attr_accessor :graphql_name, :singular
      end
    end

    def value_object?
      self.class.value_object?
    end

    def filterings
      @filterings ||= begin
        if @params.key?(:filter)
          @params[:filter].keys
        else
          []
        end
      end
    end

    def parent_field
      context[:current_arguments][:lookahead].field.owner
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

    def around_scoping(original_scope, query_hash)
      run_callbacks :query do
        super { |scope| yield scope }
      end
    end

    class_methods do
      def config
        return @config if @config
        super
        @config = @config.merge(value_objects: {}, is_value_object: false)
      end

      def attribute(*args)
        super(*args).tap do
          opts = args.extract_options!
          att = config[:attributes][args[0]]
          att[:deprecation_reason] = opts[:deprecation_reason]
          att[:null] = opts.key?(:null) ? opts[:null] : args[0] != :id
          att[:name] = args.first # for easier lookup
        end
      end

      def filter(name, *args, &blk)
        is_bool = (filters[name] && filters[name][:type] == :boolean) ||
          args[0] == :boolean
        opts = args.length == 1 ? args[0] : args[1]
        boolean_array = is_bool && opts[:single] == false
        super
        # default behavior is to force single: true
        filters[name][:single] = false if boolean_array
       
        opts = args.extract_options!
        if opts[:if]
          attributes[name][:filterable] = opts[:if]
        end
      end

      def filter_group(filter_names, *args)
        if filter_names.blank?
          config[:grouped_filters] = {}
        else
          super
        end
      end

      def value_object?
        !!config[:is_value_object]
      end

      def value_object!
        config[:is_value_object] = true
        self.adapter = ::Graphiti::Adapters::Null
        config[:filters] = {}
        config[:stats] = {}
        config[:sorts] = {}
        config[:attributes].delete(:id)
        define_method :base_scope do
          {}
        end
        define_method :resolve do |parent|
          [parent]
        end
      end

      def value_object(name, opts = {})
        opts[:array] ||= false
        opts[:null] ||= true
        config[:value_objects][name] = Graphiti::ValueObjectAssociation.new(
          name,
          parent_resource_class: self,
          resource_class: opts[:resource],
          _alias: opts[:alias],
          is_array: opts[:array],
          null: opts[:null],
          readable: opts[:readable],
          deprecation_reason: opts[:deprecation_reason]
        )
      end
    end
  end
  Graphiti::Resource.send(:prepend, ResourceExtras)

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
    def self.prepended(klass)
      klass.class_eval do
        attr_reader :join_table_alias, :edge_magic, :edge_resource
      end
    end
    
    def initialize(name, opts = {})
      @join_table_alias = opts[:join_table_alias]
      @edge_magic = opts[:edge_magic] == false ? false : true
      @edge_resource = opts[:edge_resource]
      super
    end

    def apply_belongs_to_many_filter
      super
      return unless respond_to?(:belongs_to_many_filter) # activerecord
      self_ref = self
      fk_type = parent_resource_class.attributes[:id][:type]
      fk_type = :hash if polymorphic?
      filters = resource_class.config[:filters]

      # Keep the options, apply the eq proc
      if (filter = filters[inverse_filter.to_sym])
        if filter[:operators][:eq].nil?
          filter[:operators][:eq] = proc do |scope, value|
            self_ref.belongs_to_many_filter(scope, value)
          end
        end
      end
    end
  end
  Graphiti::Sideload::ManyToMany.send(:prepend, ManyToManyExtras)

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
    if input.is_a?(ActiveSupport::TimeWithZone)
      input = input.utc.round(10).iso8601(6)
    else
      Time.zone.parse(input)
    end
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

  [:string, :integer, :float, :datetime, :precise_datetime].each do |kind|
    duped_hash = Graphiti::Util::Hash.deep_dup(Graphiti::Types[:hash])
    type = Graphiti::Types[:"#{kind}_range"] = duped_hash
    type[:canonical_name] = :"#{kind}_range"
    Graphiti::Types[:"array_of_#{kind}_ranges"] = {
      canonical_name: :"#{kind}_range",
      params: Dry::Types["strict.array"].of(type[:params]),
      read: Dry::Types["strict.array"].of(type[:read]),
      write: Dry::Types["strict.array"].of(type[:write]),
      kind: "array",
      description: "Base Type."
    }
  end

  module ActiveRecordAdapterExtras
    extend ActiveSupport::Concern

    prepended do
      alias_method :filter_precise_datetime_lt, :filter_lt
      alias_method :filter_precise_datetime_lte, :filter_lte
      alias_method :filter_precise_datetime_gt, :filter_gt
      alias_method :filter_precise_datetime_gte, :filter_gte
      alias_method :filter_precise_datetime_eq, :filter_eq
      alias_method :filter_precise_datetime_not_eq, :filter_not_eq
    end

    # TODO: integration specs mysql vs postgres for case sensitivity
    def mysql?(scope)
      mysql = ActiveRecord::ConnectionAdapters::Mysql2Adapter
      scope.model.connection.is_a?(mysql)
    end

    def filter_string_eq(scope, attribute, value, is_not: false)
      if mysql?(scope)
        clause = { attribute => value }
        is_not ? scope.where.not(clause) : scope.where(clause)
      else
        # og behavior
        column = column_for(scope, attribute)
        clause = column.lower.eq_any(value.map(&:downcase))
      end
    end

    def filter_string_eql(scope, attribute, value, is_not: false)
      if mysql?(scope)
        value = "BINARY #{value}"
      end
      # og behavior
      clause = {attribute => value}
      is_not ? scope.where.not(clause) : scope.where(clause)
    end
 
    def sanitized_like_for(scope, attribute, value, &block)
      escape_char = "\\"
      column = column_for(scope, attribute)
      map = value.map { |v|
        v = v.downcase unless mysql?(scope)
        v = Sanitizer.sanitize_like(v, escape_char)
        block.call v
      }
      arel = column
      arel = arel.lower unless mysql?(scope)
      arel.matches_any(map, escape_char, true)
    end
  end
  if defined?(Graphiti::Adapters::ActiveRecord)
    Graphiti::Adapters::ActiveRecord.send(:prepend, ActiveRecordAdapterExtras)
  end

  Graphiti::Adapters::Abstract.class_eval do
    class << self
      alias :old_default_operators :default_operators
      def default_operators
        old_default_operators.merge({
          precise_datetime: numerical_operators,
          string_enum: [:eq, :not_eq],
          integer_enum: [:eq, :not_eq],
        })
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
    def initialize(object, resource, query, opts = {})
      if resource.value_object?
        object = query.params[:parent]
        super(object, resource, query, opts)
      else
        super
      end
    end

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

class Graphiti::ValueObjectAssociation
  attr_reader :name,
    :parent_resource_class,
    :alias,
    :readable,
    :null,
    :deprecation_reason

  def initialize(
    name,
    parent_resource_class:,
    resource_class:,
    is_array: false,
    readable: nil,
    null: true,
    _alias: nil,
    deprecation_reason: nil
  )
    @name = name
    @parent_resource_class = parent_resource_class
    @resource_class = resource_class
    @readable = readable
    @array = is_array
    @alias = _alias
    @null = null
    @deprecation_reason = deprecation_reason
  end

  def array?
    !!@array
  end

  def resource_class
    @resource_class ||= Graphiti::Util::Class
      .infer_resource_class(@parent_resource_class, name)
  end

  def build_resource(parent)
    instance = resource_class.new
    instance.parent = parent
    instance
  end
end