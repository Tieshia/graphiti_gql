module GraphitiGql
  class Engine < ::Rails::Engine
    isolate_namespace GraphitiGql

    config.to_prepare do
      Dir.glob("#{Rails.root}/app/resources/**/*").each { |f| require(f) }
      GraphitiGql.schema!

      log_level = ENV.fetch('GRAPHITI_LOG_LEVEL', '1').to_i
      log_activerecord = false
      if log_level == -1 && defined?(ActiveRecord)
        log_level = 0
        log_activerecord = true
      end
      Graphiti.logger.level = log_level
      if GraphitiGql.config.log
        GraphitiGql::LogSubscriber.subscribe!(activerecord: log_activerecord)
      end
    end
  end
end
