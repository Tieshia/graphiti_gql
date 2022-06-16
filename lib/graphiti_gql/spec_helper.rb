module GraphitiGql
  module SpecHelper
    extend ActiveSupport::Concern

    class Node < OpenStruct
      def decoded_id
        Base64.decode64(self.id)
      end

      def int_id
        decoded_id.to_i
      end
    end

    class Util
      def self.underscore(hash)
        hash.deep_transform_keys { |k| k.to_s.underscore.to_sym }
      end
    end

    def query
      name = Schema.registry.key_for(resource)
      q = %|
        query #{name} (
          $filter: #{name}Filter,
          $sort: [#{name}Sort!],
          $first: Int,
          $last: Int,
          $before: String,
          $after: String,
        ) {
          #{resource.graphql_entrypoint} (
            filter: $filter,
            sort: $sort,
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

      q << %|
              }
            }
            pageInfo {
              startCursor
              endCursor
              hasNextPage
              hasPreviousPage
            }|
  
      if params[:stats]
        q << %|
            stats {|
        params[:stats].each_pair do |name, calculations|
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

    def run
      lambda do
        gql_params = params.deep_transform_keys { |key| key.to_s.camelize(:lower).to_sym }
        (gql_params[:sort] || []).each do |sort|
          sort[:att] = sort[:att].to_s.camelize(:lower)
          sort[:dir] = sort[:dir].to_s
        end
        GraphitiGql.run(query, gql_params, ctx).deep_symbolize_keys
      end
    end

    def run!
      @response = run.call
    end

    def response
      @response ||= run!
    end

    def errors
      response[:errors]
    end

    def error_messages
      response[:errors].map { |e| e[:message] }
    end

    def nodes
      return [] unless data
      nodes = edges.map { |e| Util.underscore(e[:node]) }
      nodes.map { |n| ::GraphitiGql::SpecHelper::Node.new(n) }
    end

    def data
      if response.key?(:data)
        response[:data]
      else
        raise "Tried to access 'data', but these errors were returned instead: #{error_messages.join(". ")}."
      end
    end

    def edges
      data[data.keys.first][:edges]
    end

    def stats
      Util.underscore(data[data.keys.first][:stats])
    end

    def page_info
      Util.underscore(data[data.keys.first][:pageInfo])
    end

    included do
      let(:params) { {} }
      let(:resource) { described_class }
      let(:ctx) { {} }
      let(:fields) do
        fields = []
        resource.attributes.each_pair do |name, config|
          (fields << name) if config[:readable]
        end
        fields
      end
    end
  end
end