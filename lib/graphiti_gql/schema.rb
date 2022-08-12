module GraphitiGql
  class Schema
    class PreciseDatetime < GraphQL::Types::ISO8601DateTime
      self.time_precision = 6
    end

    class DatetimeRange < GraphQL::Schema::Object
      field :from, GraphQL::Types::ISO8601DateTime
      field :to, GraphQL::Types::ISO8601DateTime
    end

    class PreciseDatetimeRange < GraphQL::Schema::Object
      field :from, PreciseDatetime
      field :to, PreciseDatetime
    end

    class StringRange < GraphQL::Schema::Object
      field :from, String
      field :to, String
    end

    class IntegerRange < GraphQL::Schema::Object
      field :from, Integer
      field :to, Integer
    end

    class FloatRange < GraphQL::Schema::Object
      field :from, Float
      field :to, Float
    end

    GQL_TYPE_MAP = {
      integer_id: String,
      string: String,
      uuid: String,
      integer: Integer,
      big_integer: GraphQL::Types::BigInt,
      float: Float,
      boolean: GraphQL::Types::Boolean,
      date: GraphQL::Types::ISO8601Date,
      datetime: GraphQL::Types::ISO8601DateTime,
      precise_datetime: PreciseDatetime,
      hash: GraphQL::Types::JSON,
      string_range: StringRange,
      integer_range: IntegerRange,
      float_range: FloatRange,
      datetime_range: DatetimeRange,
      precise_datetime_range: PreciseDatetimeRange,
      array: [GraphQL::Types::JSON],
      array_of_strings: [String],
      array_of_integers: [Integer],
      array_of_floats: [Float],
      array_of_dates: [GraphQL::Types::ISO8601Date],
      array_of_datetimes: [GraphQL::Types::ISO8601DateTime],
      array_of_precise_datetimes: [PreciseDatetime],
      array_of_string_ranges: [StringRange],
      array_of_integer_ranges: [IntegerRange],
      array_of_float_ranges: [FloatRange],
      array_of_datetime_ranges: [DatetimeRange],
      array_of_precise_datetime_ranges: [PreciseDatetimeRange]
    }

    class RelayConnectionExtension < GraphQL::Schema::Field::ConnectionExtension
      def resolve(object:, arguments:, context:)
        next_args = arguments.dup
        yield(object, next_args, arguments)
      end
    end

    def self.base_object
      klass = Class.new(GraphQL::Schema::Object)
      # TODO make this config maybe
      if defined?(ActionView)
        klass.send(:include, ActionView::Helpers::TranslationHelper)
        klass.class_eval do
          def initialize(*)
            super
            @virtual_path = "."
          end
        end
      end
      klass
    end

    def self.registry
      Registry.instance
    end

    def self.print
      GraphQL::Schema::Printer.print_schema(GraphitiGql.schema)
    end

    def initialize(resources)
      @resources = resources
    end

    def generate
      klass = Class.new(::GraphQL::Schema)
      klass.query(Query.new(@resources).build)
      klass.use(GraphQL::Batch)
      klass.connections.add(ResponseShim, Connection)
      klass.connections.add(Array, ToManyConnection)
      klass.orphan_types [GraphQL::Types::JSON]
      klass
    end
  end
end





