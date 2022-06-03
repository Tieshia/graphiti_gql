# We need the raw records, but also the proxy so we can grab stats
module GraphitiGql
  class Schema
    class ResponseShim
      attr_reader :data, :proxy

      def initialize(data, proxy)
        @data = data
        @proxy = proxy
      end
    end
  end
end