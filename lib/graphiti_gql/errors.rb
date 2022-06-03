module GraphitiGql
  module Errors
    class Base < StandardError;end

    class UnsupportedStats < Base
      def message
        "You're requesting stats for multiple parent nodes. Currently, we only support this when there is a single parent node, or when using the ActiveRecord adapter."
      end
    end

    class UnauthorizedField < Base
      def initialize(field)
        @field = field
      end

      def message
        "You are not authorized to read field #{@field}"
      end
    end
  end
end