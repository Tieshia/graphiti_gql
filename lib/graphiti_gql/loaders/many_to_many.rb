module GraphitiGql
  module Loaders
    class ManyToMany < Many
      def assign(ids, proxy)
        records = proxy.data
        thru = @sideload.foreign_key.keys.first
        fk = @sideload.foreign_key[thru]
        ids.each do |id|
          match = ->(thru) { thru.send(fk) == id }
          corresponding = records.select { |record| record.send(thru).any?(&match) }
          fulfill(id, [corresponding, proxy])
        end
      end
    end
  end
end
