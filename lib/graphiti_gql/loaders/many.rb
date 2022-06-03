module GraphitiGql
  module Loaders
    class Many < GraphQL::Batch::Loader
      def self.factory(sideload, params)
        if sideload.polymorphic_as
          PolymorphicHasMany.for(sideload, params)
        elsif sideload.type == :many_to_many
          ManyToMany.for(sideload, params)
        else
          HasMany.for(sideload, params)
        end
      end

      def initialize(sideload, params)
        @sideload = sideload
        @params = params
      end

      def perform(ids)
        raise ::Graphiti::Errors::UnsupportedPagination if paginating? && ids.length > 1
        raise Errors::UnsupportedStats if requesting_stats? && ids.length > 1 && !can_group?

        build_params(ids)
        proxy = @sideload.resource.class.all(@params)
        assign(ids, proxy)
      end

      def assign(ids, proxy)
        raise "implement in subclass"
      end

      private

      def build_params(ids)
        @params[:filter] ||= {}

        if @sideload.polymorphic_as
          type = ids[0][:"#{@sideload.polymorphic_as}_type"]
          foreign_keys = ids.map { |id| id[@sideload.foreign_key] }
          @params[:filter][:"#{@sideload.polymorphic_as}_type"] = type
          @params[:filter][@sideload.foreign_key] = foreign_keys.join(",")
        elsif @sideload.type == :many_to_many
          fk = @sideload.foreign_key.values.first
          @params[:filter].merge!(fk => { eq: ids.join(",") })
        else
          @params[:filter].merge!(@sideload.foreign_key => { eq: ids.join(",") })
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