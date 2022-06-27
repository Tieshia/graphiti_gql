module GraphitiGql
  module Loaders
    class HasMany < Many
      def assign(parent_records, proxy)
        records = proxy.data
        map = records.group_by { |record| record.send(@sideload.foreign_key) }
        parent_records.each do |pr|
          data = [map[pr.send(@sideload.primary_key)] || [], proxy]
          fulfill(pr, data)
        end
      end
    end
  end
end