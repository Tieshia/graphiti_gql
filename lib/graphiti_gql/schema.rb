module GraphitiGql
  class Schema
    GQL_TYPE_MAP = {
      integer_id: String,
      string: String,
      uuid: String,
      integer: Integer,
      float: Float,
      boolean: GraphQL::Schema::Member::GraphQLTypeNames::Boolean,
      date: GraphQL::Types::ISO8601Date,
      datetime: GraphQL::Types::ISO8601DateTime,
      hash: GraphQL::Types::JSON,
      array: [GraphQL::Types::JSON],
      array_of_strings: [String],
      array_of_integers: [Integer],
      array_of_floats: [Float],
      array_of_dates: [GraphQL::Types::ISO8601Date],
      array_of_datetimes: [GraphQL::Types::ISO8601DateTime]
    }

    class RelayConnectionExtension < GraphQL::Schema::Field::ConnectionExtension
      def resolve(object:, arguments:, context:)
        next_args = arguments.dup
        yield(object, next_args, arguments)
      end
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
      klass
    end
  end
end





