module GraphitiGql
  module Loaders
    class FakeRecord < Struct.new(:id, :type)
    end

    class BelongsTo < GraphQL::Batch::Loader
      def initialize(sideload, params)
        @sideload = sideload
        @params = params
      end

      def perform(ids)
        # process nils
        ids.each { |id| fulfill(id, nil) if id.nil? }
        ids.compact!
        return if ids.empty?

        if @params[:simpleid]
          if @sideload.type == :polymorphic_belongs_to
            ids.each do |id|
              child = @sideload.children.values.find { |c| c.group_name == id[:type].to_sym }
              type = Schema::Registry.instance.get(child.resource.class, interface: false)[:type]
              fulfill(id, FakeRecord.new(id[:id], type))
            end
          else
            type = Schema::Registry.instance.get(@sideload.resource.class)[:type]
            ids.each { |id| fulfill(id, FakeRecord.new(id, type)) }
          end
          return
        end

        if @sideload.type == :polymorphic_belongs_to
          groups = ids.group_by { |hash| hash[:type] }
          payload = {}
          groups.each_pair do |key, val|
            payload[key] = val.map { |v| v[:id] }
          end
          futures = []
          payload.each_pair do |key, value|
            params = { filter: {} }
            klass = @sideload.children.values.find { |c| c.group_name == key.to_sym }
            params = {
              filter: { id: { eq: value.join(",") } }
            }

            futures << Concurrent::Future.execute do
               { type: key, data: klass.resource.class.all(params).data }
            end
          end
          values = futures.map(&:value)
          ids.each do |id|
            val = values.find { |v| v[:type] == id[:type] }
            fulfill(id, val[:data][0])
          end
        else
          params = {filter: {id: {eq: ids.join(",")}}}
          resource = Schema.registry.get(@sideload.resource.class)[:resource]
          records = resource.all(params).data
          map = records.index_by { |record| record.id }
          ids.each { |id| fulfill(id, map[id]) }
        end
      end
    end
  end
end