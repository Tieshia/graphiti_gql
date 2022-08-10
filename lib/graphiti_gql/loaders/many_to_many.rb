module GraphitiGql
  module Loaders
    class ManyToMany < Many
      def assign(parent_records, proxy)
        thru = @sideload.foreign_key.keys.first
        fk = @sideload.foreign_key[thru]
        add_join_table_magic(proxy)
        records = proxy.data
        parent_records.each do |pr|
          corresponding = records.select do |record|
            record.send(:"_edge_#{fk}") == pr.send(@sideload.primary_key)
          end
          fulfill(pr, [corresponding, proxy])
        end
      end

      private

      def thru_model
        thru = @sideload.foreign_key.keys.first
        reflection = @sideload.parent_resource.model.reflect_on_association(thru)
        reflection.klass
      end

      def add_join_table_magic(proxy)
        return unless @sideload.edge_magic
        if defined?(ActiveRecord) && proxy.resource.model.ancestors.include?(ActiveRecord::Base)
          thru_table_name = @sideload.join_table_alias || thru_model.table_name
          names = thru_model.column_names.map do |n|
            next if n == :id
            "#{thru_table_name}.#{n} as _edge_#{n}"
          end
          scope = proxy.scope.object
          scope = scope.select(["#{proxy.resource.model.table_name}.*"] + names)
          proxy.scope.object = scope
        end
      end
    end
  end
end
