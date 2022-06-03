module GraphitiGql
  class Schema
    class Util
      def self.params_from_args(arguments)
        lookahead = arguments.delete(:lookahead)
        params = arguments.as_json.deep_transform_keys { |key| key.to_s.underscore.to_sym }
        if params[:sort]
          params[:sort] = Util.transform_sort_param(params[:sort])
        end

        if (first = params.delete(:first))
          params[:page] ||= {}
          params[:page][:size] = first
        end


        if (last = params.delete(:last))
          params[:page] ||= {}
          params[:page][:size] = last
          params[:reverse] = true
        end

        if (after = params.delete(:after))
          params[:page] ||= {}
          params[:page][:after] = after
       end

        if (before = params.delete(:before))
          params[:page] ||= {}
          params[:page][:before] = before
        end

        if (id = params.delete(:id))
          params[:filter] ||= {}
          params[:filter][:id] = { eq: id }
        end

        if lookahead.selects?(:stats)
          stats = lookahead.selection(:stats)
          payload = {}
          stats.selections.map(&:name).each do |name|
            payload[name] = stats.selection(name).selections.map(&:name)
          end
          params[:stats] = payload

          # only requesting stats
          if lookahead.selections.map(&:name) == [:stats]
            params[:page] = { size: 0 }
          end
        end

        params
      end

      def self.transform_sort_param(sorts)
        sorts.map do |sort_param|
          sort = sort_param[:att].underscore
          sort = "-#{sort}" if sort_param[:dir] == "desc"
          sort
        end.join(",")
      end

      def self.is_readable_sideload!(sideload)
        readable = sideload.instance_variable_get(:@readable)
        if readable.is_a?(Symbol)
          path = Graphiti.context[:object][:current_path].join(".")
          unless sideload.parent_resource.send(readable)
            raise Errors::UnauthorizedField.new(path)
          end
        end
      end
    end
  end
end