module GraphitiGql
  module Loaders
    class HasMany < Many
      def assign(parent_records, proxy)
        records = proxy.data

        foreign_key = @sideload.foreign_key
        config = @sideload.resource.attributes[foreign_key]
        if config && config[:alias]
          foreign_key = config[:alias]
        end

        map = records.group_by { |record| record.send(foreign_key) }
        parent_records.each do |pr|
          data = [map[pr.send(@sideload.primary_key)] || [], proxy]
          fulfill(pr, data)
        end
      end
    end
  end
end