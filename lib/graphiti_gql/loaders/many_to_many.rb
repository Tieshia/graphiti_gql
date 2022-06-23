module GraphitiGql
  module Loaders
    class ManyToMany < Many
      def assign(ids, proxy)
        thru = @sideload.foreign_key.keys.first
        fk = @sideload.foreign_key[thru]
        add_join_table_magic(proxy)
        records = proxy.data
        ids.each do |id|
          corresponding = records.select do |record|
            record.send(:"_edge_#{fk}") == id
          end
          fulfill(id, [corresponding, proxy])
        end
      end

      private

      def add_join_table_magic(proxy)
        if defined?(ActiveRecord) && proxy.resource.model.ancestors.include?(ActiveRecord::Base)
          thru = @sideload.foreign_key.keys.first
          thru_model = proxy.resource.model.reflect_on_association(thru).klass
          names = thru_model.column_names.map do |n|
            "#{thru_model.table_name}.#{n} as _edge_#{n}"
          end
          scope = proxy.scope.object
          scope = scope.select(["#{proxy.resource.model.table_name}.*"] + names)
          proxy.scope.object = scope
        end
      end
    end
  end
end
