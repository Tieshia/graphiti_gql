module GraphitiGql
  module ActiveResource
    extend ActiveSupport::Concern

    class Node < OpenStruct
      def initialize(resource, hash)
        @resource = resource
        hash.each_pair do |key, value|
          if value.is_a?(Hash)
            if (sideload = resource.sideload(key))
              if value.key?(:edges) 
                hash[key] = value[:edges].map { |v| Node.new(sideload.resource.class, v[:node]) }
              else
                hash[key] = Node.new(sideload.resource.class, value)
              end
            end
          end
        end
        super(hash)
      end

      def decoded_id
        Base64.decode64(self.id)
      end

      def int_id
        decoded_id.to_i
      end
    end

    class Proxy
      def initialize(resource, params, ctx)
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

      def nodes
        return [] unless data
        nodes = edges.map { |e| underscore(e[:node]) }
        nodes.map { |n| Node.new(@resource, n) }
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

      def query
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
            q << %|
                  #{inc.to_s.camelize(:lower)} {|
            if !to_one
              q << %|
                    edges {
                      node {|
            end

            r = @resource.sideload(inc.to_sym).resource
            r.attributes.each_pair do |name, config|
              next unless config[:readable]
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
      def gql(params = {}, ctx = {})
        Proxy.new(self, params, ctx)
      end
    end
  end
end

Graphiti::Resource.send(:include, GraphitiGql::ActiveResource)