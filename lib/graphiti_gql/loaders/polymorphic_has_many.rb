module GraphitiGql
  module Loaders
    class PolymorphicHasMany < Many
      def assign(parent_records, proxy)
        records = proxy.data
        parent_records.each do |pr|
          corresponding = records.select do |record|
            child_ft = record.send("#{@sideload.polymorphic_as}_type")
            child_fk = record.send(@sideload.foreign_key)
            parent_ft = pr.class.name
            parent_fk = pr.send(@sideload.primary_key)
            child_ft == parent_ft && child_fk == parent_fk
          end
          data = [corresponding || [], proxy]
          fulfill(pr, data)
        end
      end
    end
  end
end
