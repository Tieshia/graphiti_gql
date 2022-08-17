module GraphitiGql
  class ExceptionHandler
    attr_reader :error, :context, :field
    class_attribute :registry, :log, :notify, :default_message, :default_code

    self.registry = {}
    self.default_message = "We're sorry, something went wrong."
    self.default_code = 500

    def self.register_exception(err, opts)
      registry[err] = opts
    end

    register_exception Graphiti::Errors::RecordNotFound, code: 404
    register_exception Graphiti::Errors::SingularSideload, code: 400
    register_exception Graphiti::Errors::InvalidAttributeAccess, code: 403
    register_exception GraphitiGql::Errors::UnsupportedLast, code: 400

    def initialize(err, obj, args, ctx, field)
      @error = err
      @obj = obj
      @args = args
      @context = ctx
      @field = field
      @config = get_config(err)
    end

    def notify
      # noop
    end

    def log
      # noop
    end

    def handle
      notify if @config[:notify] != false
      log if @config[:log] != false

      message = @config[:message] ? err.message : default_message
      code = @config[:code] || default_code
      raise GraphQL::ExecutionError.new(message, extensions: { code: code })
    end

    private

    def get_config(error)
      registered = registry.find { |e, _| error.is_a?(e) }
      registered ? registered[1] : {}
    end
  end
end