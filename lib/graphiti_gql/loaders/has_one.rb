module GraphitiGql
  module Loaders
    class HasOne < Many
      def assign(parent_records, proxy)
        records = proxy.data
        parent_records.each do |pr|
          corresponding = records.find do |r|
            r.send(@sideload.foreign_key) == pr.send(@sideload.primary_key)
          end
          fulfill(pr, corresponding)
        end
      end
    end
  end
end