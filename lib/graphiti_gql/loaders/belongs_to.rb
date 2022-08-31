module GraphitiGql
  module Loaders
    class FakeRecord < Struct.new(:id, :type, :graphiti_resource)
      def initialize(*args)
        super
        @__graphiti_resource = graphiti_resource
      end
    end

    class BelongsTo < GraphQL::Batch::Loader
      def initialize(sideload, params)
        @sideload = sideload
        @params = params
      end

      def perform(ids)
        Graphiti.broadcast("association", { sideload: @sideload })
        # process nils
        ids.each { |id| fulfill(id, nil) if id.nil? }
        ids.compact!
        return if ids.empty?

        if @params[:simpleid] && !to_polymorphic_resource?
          if @sideload.type == :polymorphic_belongs_to
            ids.each do |id|
              child = @sideload.children.values.find { |c| c.group_name == id[:type].to_sym }
              type = Schema::Registry.instance.get(child.resource.class, interface: false)[:type]
              fulfill(id, FakeRecord.new(id[:id], type, child.resource))
            end
          else
            type = Schema::Registry.instance.get(@sideload.resource.class)[:type]
            ids.each { |id| fulfill(id, FakeRecord.new(id, type, @sideload.resource)) }
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
            filter_ids = value.map { |id| @sideload.resource.class.gid(id.to_s) }
            params = @params.merge({
              filter: { id: { eq: filter_ids } }
            })

            futures << Concurrent::Future.execute do
               { type: key, data: klass.resource.class.all(params).data }
            end
          end
          values = futures.map(&:value)
          ids.each do |id|
            records_for_type = values.find { |v| v[:type] == id[:type] }
            corresponding = records_for_type[:data].find { |r| r.id == id[:id] }
            fulfill(id, corresponding)
          end
        else
          resource = Schema.registry.get(@sideload.resource.class)[:resource]
          params = @params.deep_dup
          unless resource.singular
            filter_ids = ids.map { |id| @sideload.resource.class.gid(id.to_s) }
            params[:filter] = {id: { eq: filter_ids } }
          end
          records = resource.all(params).data
          if resource.singular
            ids.each { |id| fulfill(id, records[0]) }
          else
            map = records.index_by { |record| record.id }
            ids.each { |id| fulfill(id, map[id]) }
          end
        end
      end

      private

      def to_polymorphic_resource?
        @sideload.resource.polymorphic? && @sideload.type != :polymorphic_belongs_to
      end
    end
  end
end