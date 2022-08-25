module GraphitiGql
  class Schema
    module Fields
      class Stats
        def initialize(resource)
          @resource = resource
        end

        def apply(type)
          type.field :stats, build_stat_class, null: false
          type.define_method :stats do
            Graphiti.broadcast('before_stats', {})
            # Process grouped (to-many relationship) stats
            Graphiti.broadcast('after_stats', {}) do
              stats = object.proxy.stats.deep_dup
              stats.each_pair do |attr, calc|
                calc.each_pair do |calc_name, value|
                  if value.is_a?(Hash)
                    stats[attr][calc_name] = value[parent.id]
                  end
                end
              end
              stats
            end
          end
          type
        end

        private

        def build_stat_class
          name = Registry.instance.key_for(@resource)
          stat_graphql_name = "#{name}Stats"
          return Registry.instance[stat_graphql_name][:type] if Registry.instance[stat_graphql_name]
          klass = Class.new(Schema.base_object)
          klass.graphql_name(stat_graphql_name)
          @resource.stats.each_pair do |name, config|
            calc_class = build_calc_class(stat_graphql_name, name, config.calculations.keys)
            klass.field name, calc_class, null: false
          end
          Registry.instance[stat_graphql_name] = { type: klass }
          klass
        end
    
        def build_calc_class(stat_graphql_name, stat_name, calculations)
          name = "#{stat_graphql_name}#{stat_name}Calculations"
          klass = Class.new(Schema.base_object)
          klass.graphql_name(name)
          calculations.each do |calc|
            klass.field calc, Float, null: false
          end
          klass
        end
      end
    end
  end
end