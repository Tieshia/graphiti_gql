# TODO: Rushing here so tests are in app and code is gross
module GraphitiGql
  module ActiveResource
    extend ActiveSupport::Concern

    class Node < OpenStruct
      def initialize(hash, resource = nil)
        @resource = resource
        @edges = {}
        @node_id = hash.delete(:node_id)
        hash.each_pair do |key, value|
          if value.is_a?(Hash)
            if (sideload = resource.sideload(key))
              if value.key?(:edges) 
                @edges[key] = value[:edges].map do |edge|
                  node_id = edge[:node][:id]
                  Node.new(edge.except(:node).merge(node_id: node_id))
                end
                hash[key] = value[:edges].map { |v| Node.new(v[:node], sideload.resource.class) }
              else
                hash[key] = Node.new(value, sideload.resource.class)
              end
            end
          end
        end
        super(hash)
      end

      def edge(name, node_id)
        found = @edges[name].empty? ? nil : @edges[name]
        if found && node_id
          found.find { |f| f.instance_variable_get(:@node_id) == node_id.to_s }
        else
          found
        end
      end

      def decoded_id
        Base64.decode64(self.id)
      end

      def int_id
        decoded_id.to_i
      end
    end

    class Proxy
      def initialize(resource, params, ctx, query)
        @query = query
        @resource = resource
        @ctx = ctx
        @params = params.deep_transform_keys { |key| key.to_s.camelize(:lower).to_sym }
        (@params[:sort] || []).each do |sort|
          sort[:att] = sort[:att].to_s.camelize(:lower)
          sort[:dir] = sort[:dir].to_s
        end
      end

      def to_h(symbolize_keys: true)
        result = GraphitiGql.run(query, @params, @ctx)
        result = result.deep_symbolize_keys if symbolize_keys
        @response = result
        result
      end

      def node(id)
        nodes.find { |n| n.id == id.to_s }
      end

      def nodes
        return [] unless data
        elements = if edges
          edges.map { |e| e[:node] }
        else
          data[data.keys.first][:nodes] || []
        end
        elements.map { |n| Node.new(underscore(n), @resource) }
      end
      alias :to_a :nodes

      def response
        @response ||= to_h
      end

      def data
        if response.key?(:data)
          response[:data]
        else
          raise "Tried to access 'data', but these errors were returned instead: #{error_messages.join(". ")}."
        end
      end

      def errors
        response[:errors]
      end
  
      def error_messages
        response[:errors].map { |e| e[:message] }
      end

      def edges
        data[data.keys.first][:edges]
      end
  
      def stats
        underscore(data[data.keys.first][:stats])
      end
  
      def page_info
        underscore(data[data.keys.first][:pageInfo])
      end

      # barf
      def query
        return @query if @query

        name = Schema.registry.key_for(@resource)
        filter_bang = "!" if @resource.filters.values.any? { |f| f[:required] }
        sortvar = "$sort: [#{name}Sort!]," if @resource.sorts.any?

        if !(fields = @params[:fields])
          fields = []
          @resource.attributes.each_pair do |name, config|
            (fields << name) if config[:readable]
          end
        end

        q = %|
          query #{name} (
            $filter: #{name}Filter#{filter_bang},
            #{sortvar}
            $first: Int,
            $last: Int,
            $before: String,
            $after: String,
          ) {
            #{@resource.graphql_entrypoint} (
              filter: $filter,
              #{ 'sort: $sort,' if sortvar }
              first: $first,
              last: $last,
              before: $before,
              after: $after,
            ) {
              edges {
                node {|

        fields.each do |name|
          next if name.is_a?(Hash)
          q << %|
                  #{name.to_s.camelize(:lower)}|
        end

        if @params[:include]
          includes = Array(@params[:include])
          # NB HASH (?)
          includes.each do |inc|
            sideload = @resource.sideload(inc.to_sym)
            to_one = [:belongs_to, :has_one, :polymorphic_belongs_to].include?(sideload.type)
            indent = "    " if !to_one

            edge_fields = []
            runtime_sideload_fields = @params[:fields].find { |f| f.is_a?(Hash) && f.key?(inc.to_sym) }
            if runtime_sideload_fields
              runtime_sideload_fields = runtime_sideload_fields.values
              edge_fields = runtime_sideload_fields.find { |f| f.is_a?(Hash) && f.key?(:edge) }
              runtime_sideload_fields = runtime_sideload_fields.reject { |f| f.is_a?(Hash) }
              edge_fields = edge_fields[:edge] if edge_fields
            end

            q << %|
                  #{inc.to_s.camelize(:lower)} {|
            if !to_one
              q << %|
                    edges {|

              edge_fields.each do |ef|
                q << %|
                      #{ef.to_s.camelize(:lower)}|
              end

              q << %|
                      node {|
            end

            sideload_fields = runtime_sideload_fields
            if sideload_fields.blank?
              sideload_fields = @resource.sideload(inc.to_sym).resource.attributes.select { |_, config| config[:readable] }.map(&:first)
            end
            sideload_fields.each do |name|
              q << %|
                    #{indent}#{name.to_s.camelize(:lower)}|
            end

            if to_one
              q << %|
                  }|
            else
              q << %|
                      }
                    }
                  }|
            end
          end
        end
  
        q << %|
                }
              }
              pageInfo {
                startCursor
                endCursor
                hasNextPage
                hasPreviousPage
              }|

        if @params[:stats]
          q << %|
              stats {|
          @params[:stats].each_pair do |name, calculations|
            q << %|
                #{name.to_s.camelize(:lower)} {|
            Array(calculations).each do |calc|
              q << %|
                  #{calc.to_s.camelize(:lower)}|
            end
    
            q << %|
                }|
          end
          q << %|
              }|          
        end

        q << %|
            }
          }
        |

        q
      end

      private

      def underscore(hash)
        hash.deep_transform_keys { |k| k.to_s.underscore.to_sym }
      end
    end

    class_methods do
      def gql(params = {}, ctx = {}, query = nil)
        Proxy.new(self, params, ctx, query)
      end
    end
  end
end

Graphiti::Resource.send(:include, GraphitiGql::ActiveResource)