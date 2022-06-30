module GraphitiGql
  module SpecHelper
    extend ActiveSupport::Concern

    included do
      extend Forwardable
      def_delegators :result,
        :page_info,
        :errors,
        :error_messages,
        :nodes,
        :stats

      if defined?(RSpec)
        let(:params) do
          fields = []
          resource.attributes.each_pair do |name, config|
            (fields << name) if config[:readable]
          end
          { fields: fields }
        end
        let(:resource) { described_class }
        let(:ctx) { {} }

        def self.only_fields(*fields)
          before do
            fields.each { |f| params[:fields].select! { |p| p == f } }
          end
        end

        def self.except_fields(*fields)
          before do
            fields.each { |f| params[:fields].reject! { |p| p == f } }
          end
        end
      end
    end

    def gql_datetime(timestamp, precise = false)
      if precise
        timestamp.utc.round(10).iso8601(6)
      else
        DateTime.parse(timestamp.to_s).iso8601
      end
    end

    def run
      lambda do
        proxy = resource.gql(params, ctx)
        proxy.to_h
        proxy
      end
    end

    def run!
      @result = run.call
    end

    def result
      @result ||= run!
    end
  end
end