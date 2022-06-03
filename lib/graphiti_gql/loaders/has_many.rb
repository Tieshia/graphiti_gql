module GraphitiGql
  module Loaders
    class HasMany < Many
      def assign(ids, proxy)
        records = proxy.data
        map = records.group_by { |record| record.send(@sideload.foreign_key) }
        ids.each do |id|
          data = [map[id] || [], proxy]
          fulfill(id, data)
        end
      end
    end
  end
end