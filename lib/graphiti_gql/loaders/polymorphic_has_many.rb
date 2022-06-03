module GraphitiGql
  module Loaders
    class PolymorphicHasMany < Many
      def assign(ids, proxy)
        records = proxy.data
        ids.each do |id|
          corresponding = records.select do |record|
            record.send("#{@sideload.polymorphic_as}_type") == id[:"#{@sideload.polymorphic_as}_type"] &&
              record.send(@sideload.foreign_key) == id[@sideload.foreign_key]
          end
          data = [corresponding || [], proxy]
          fulfill(id, data)
        end
      end
    end
  end
end
