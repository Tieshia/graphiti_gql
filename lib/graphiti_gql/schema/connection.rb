module GraphitiGql
  class Schema
    class Connection < ::GraphQL::Pagination::Connection
      def nodes
        return @items if @run_once
        @proxy = @items.proxy
        @items = @items.data
        @run_once = true
        @items
      end

      def proxy
        nodes
        @proxy
      end

      def has_previous_page
        proxy.pagination.has_previous_page?
      end

      def has_next_page
        nodes
        return false if @items.length.zero?
        cursor = JSON.parse(Base64.decode64(cursor_for(@items.last)))
        cursor["offset"] < @proxy.pagination.send(:item_count)
      end

      def cursor_for(item)
        nodes
        starting_offset = 0
        page_param = proxy.query.pagination
        if (page_number = page_param[:number])
          page_size = page_param[:size] || proxy.resource.default_page_size
          starting_offset = (page_number - 1) * page_size
        end
  
        if (cursor = page_param[:after])
          starting_offset = cursor[:offset]
        end
  
        current_offset = @items.index(item)
        offset = starting_offset + current_offset + 1 # (+ 1 b/c o-base index)
        Base64.encode64({offset: offset}.to_json).chomp
      end
    end

    class ToManyConnection < Connection
      def nodes
        return @items if @run_once
        @proxy = @items[1]
        @items = @items[0]
        @run_once = true
        @items
      end
    end
  end
end