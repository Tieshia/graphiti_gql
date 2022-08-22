module GraphitiGql
  class Schema
    class ListArguments
      class SortDirType < GraphQL::Schema::Enum
        graphql_name "SortDir"
        value "asc", "Ascending"
        value "desc", "Descending"
      end

      def initialize(resource, sideload = nil)
        @resource = resource
        @sideload = sideload
      end

      def apply(field)
        define_filters(field) unless @resource.filters.empty?
        define_sorts(field) unless @resource.sorts.empty?
      end

      private

      def registry
        Registry.instance
      end

      # TODO - when no sorts schema error, when no filters schema error
      def define_filters(field)
        filter_type = generate_filter_type(field)
        required = @resource.filters.any? { |name, config|
          value = !!config[:required]
          if @sideload
            fk = @sideload.foreign_key
            fk = fk.values.first if fk.is_a?(Hash)
            value && fk != name
          else
            value
          end
        }
        required = true if @resource.grouped_filters.any? && !@sideload
        field.argument :filter, filter_type, required: required
      end
    
      def generate_filter_type(field)
        type_name = "#{registry.key_for(@resource)}Filter"
        if (registered = registry[type_name])
          return registered[:type]
        end
        klass = Class.new(GraphQL::Schema::InputObject)
        klass.graphql_name type_name
        required_via_group = []
        if (group = @resource.grouped_filters).present?
          if group[:required] == :all
            required_via_group = group[:names].map(&:to_sym)
          end
        end
        @resource.filters.each_pair do |name, config|
          next if config[:schema] == false

          attr_type = generate_filter_attribute_type(type_name, name, config)
          required = !!config[:required] || required_via_group.include?(name)
          klass.argument name.to_s.camelize(:lower),
            attr_type,
            required: required
        end
        registry[type_name] = { type: klass }
        klass
      end
    
      def generate_filter_attribute_type(type_name, filter_name, filter_config)
        klass = Class.new(GraphQL::Schema::InputObject)
        filter_graphql_name = "#{type_name}Filter#{filter_name.to_s.camelize(:lower)}"
        klass.graphql_name(filter_graphql_name)
        filter_config[:operators].keys.each do |operator|
          graphiti_type = Graphiti::Types[filter_config[:type]]
          type = graphiti_type[:graphql_type]
          if !type
            canonical_graphiti_type = Graphiti::Types
              .name_for(filter_config[:type])
            type = GQL_TYPE_MAP[canonical_graphiti_type]
            type = String if filter_name == :id
          end

          if (allowlist = filter_config[:allow])
            type = define_allowlist_type(filter_graphql_name, allowlist)
          end
  
          type = [type] unless !!filter_config[:single]
          klass.argument operator, type, required: false
        end
        klass
      end
    
      def define_allowlist_type(filter_graphql_name, allowlist)
        name = "#{filter_graphql_name}Allow"
        if (registered = registry[name])
          return registered[:type]
        end
        klass = Class.new(GraphQL::Schema::Enum)
        klass.graphql_name(name)
        allowlist.each do |allowed|
          klass.value(allowed)
        end
        registry[name] = { type: klass }
        klass
      end

      def define_sorts(field)
        sort_type = generate_sort_type
        field.argument :sort, [sort_type], required: false
      end

      def generate_sort_att_type
        type_name = "#{registry.key_for(@resource)}SortAtt"
        if (registered = registry[type_name])
          return registered[:type]
        end
        klass = Class.new(GraphQL::Schema::Enum) {
          graphql_name(type_name)
        }
        @resource.sorts.each_pair do |name, config|
          klass.value name.to_s.camelize(:lower), "Sort by #{name}"
        end
        registry[type_name] = { type: klass }
        klass
      end
  
      def generate_sort_type
        type_name = "#{registry.key_for(@resource)}Sort"
        if (registered = registry[type_name])
          return registered[:type]
        end
        att_type = generate_sort_att_type
        klass = Class.new(GraphQL::Schema::InputObject) {
          graphql_name type_name
          argument :att, att_type, required: true
          argument :dir, SortDirType, required: true
        }
        registry[type_name] = { type: klass }
        klass
      end
    end
  end
end