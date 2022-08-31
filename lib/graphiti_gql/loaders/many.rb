module GraphitiGql
  module Loaders
    class Many < GraphQL::Batch::Loader
      def self.factory(sideload, params)
        if sideload.polymorphic_as
          PolymorphicHasMany.for(sideload, params)
        elsif sideload.type == :many_to_many
          ManyToMany.for(sideload, params)
        elsif sideload.type == :has_one
          HasOne.for(sideload, params)
        else
          HasMany.for(sideload, params)
        end
      end

      def initialize(sideload, params)
        @sideload = sideload
        @params = params.merge(typecast_filters: false)
      end

      def perform(parent_records)
        Graphiti.broadcast("association", { sideload: @sideload })
        raise ::Graphiti::Errors::UnsupportedPagination if paginating? && parent_records.length > 1
        raise Errors::UnsupportedStats if requesting_stats? && parent_records.length > 1 && !can_group?

        ids = parent_records.map do |pr|
          pk = pr.send(@sideload.primary_key)
          if @sideload.polymorphic_as
            hash = {}
            hash[@sideload.foreign_key] = pk
            hash[:"#{@sideload.polymorphic_as}_type"] = pr.class.name
            hash
          else
            pk
          end
        end
        ids.compact!

        build_params(ids, parent_records)
        resource = Schema.registry.get(@sideload.resource.class)[:resource]
        proxy = resource.all(@params)
        assign(parent_records, proxy)
      end

      def assign(ids, proxy)
        raise "implement in subclass"
      end

      private

      def build_params(ids, parent_records)
        @params[:filter] ||= {}

        if @sideload.polymorphic_as
          type = ids[0][:"#{@sideload.polymorphic_as}_type"]
          foreign_keys = ids.map { |id| id[@sideload.foreign_key] }
          foreign_keys.map! { |id| @sideload.parent_resource.class.gid(id) }
          @params[:filter][:"#{@sideload.polymorphic_as}_type"] = type
          @params[:filter][@sideload.foreign_key] = foreign_keys
        elsif @sideload.type == :many_to_many
          filter_ids = ids.map { |id| @sideload.parent_resource.class.gid(id) }
          fk = @sideload.foreign_key.values.first
          @params[:filter].merge!(fk => { eq: filter_ids })
        elsif !@sideload.parent_resource.class.singular
          filter_ids = ids.map { |id| @sideload.parent_resource.class.gid(id) }
          @params[:filter].merge!(@sideload.foreign_key => { eq: filter_ids })
        end

        if @params[:stats]
          group_by = if @sideload.type ==:many_to_many
            @sideload.foreign_key.values.first
          else
            @sideload.foreign_key
          end
          @params[:stats][:group_by] = group_by
        end

        unless @params.key?(:page) && @params[:page].key?(:size)
          @params[:page] ||= {}
          @params[:page][:size] = 999
        end

        if @sideload.params_proc
          @sideload.params_proc.call(@params, parent_records)
        end
      end

      def paginating?
        pagination_key_present = @params.key?(:page) &&
          [:size, :last, :before, :after].any? { |arg| @params[:page].key?(arg) }
        pagination_key_present && @params[:page][:size] != 0 # stats
      end

      def requesting_stats?
        @params.key?(:stats)
      end

      def can_group?
        @sideload.resource.adapter.can_group?
      end
    end
  end
end