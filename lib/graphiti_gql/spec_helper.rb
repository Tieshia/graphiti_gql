module GraphitiGql
  module SpecHelper
    extend ActiveSupport::Concern

    module ScopeTrackable
      def self.prepended(klass)
        klass.class_eval do
          class << self
            attr_accessor :resolved_scope
          end
        end
      end

      def resolve(scope)
        self.class.resolved_scope = scope
        super
      end
    end

    included do
      extend Forwardable
      def_delegators :result,
        :page_info,
        :errors,
        :error_messages,
        :nodes,
        :node,
        :stats

      Graphiti::Resource.send(:prepend, ScopeTrackable)

      if defined?(RSpec)
        let(:params) { {} }
        let(:resource) { described_class }
        let(:ctx) { {} }
        let(:only_fields) { [] }
        let(:except_fields) { [] }

        def self.only_fields(*fields)
          let(:only_fields) { fields }
        end

        def self.except_fields(*fields)
          let(:except_fields) { fields }
        end

        let(:fields) do
          fields = []
          resource.attributes.each_pair do |name, config|
            (fields << name) if config[:readable]
          end
          if respond_to?(:only_fields) && only_fields.present?
            fields.select! { |f| only_fields.include?(f) }
          elsif respond_to?(:except_fields) && except_fields.present?
            fields.reject! { |f| except_fields.include?(f) }
          end
          fields
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

    def proxy
      q = defined?(query) ? query : nil
      with_pagination = respond_to?(:with_pagination) ? send(:with_pagination) : false
      opts = { with_pagination: with_pagination }
      resource.gql(params.merge(fields: fields), ctx, q, opts)
    end


    def run
      lambda do
        instance = proxy
        instance.run!
        instance
      end
    end

    def run!
      @json = nil
      @result = run.call
    end

    def result
      @result ||= run!
    end

    def json
      @json ||= result.response
    end
  end
end