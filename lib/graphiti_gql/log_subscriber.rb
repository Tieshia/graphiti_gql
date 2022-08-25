# TODO: remove OG graphiti debugger
module GraphitiGql
  class LogSubscriber
    def self.subscribe!(activerecord: false)
      instance = LogSubscriber.new
      instance.subscribe!('resolve', :on_data)
      instance.subscribe!('schema.before_execute', :on_schema_before_execute)
      instance.subscribe!('schema.execute', :on_schema_execute)
      instance.subscribe!('resource.all', :on_resource_all)
      instance.subscribe!('association', :on_association)
      instance.subscribe!('before_stats', :on_before_stats)
      instance.subscribe!('after_stats', :on_after_stats)
      if activerecord
        ActiveSupport::Notifications
          .subscribe("sql.active_record", instance.method(:on_activerecord))
      end
    end

    def initialize
      @chunks = {}
    end

    def subscribe!(name, method_name)
      ActiveSupport::Notifications
        .subscribe("#{name}.graphiti", method(method_name))
    end

    def on_data(name, start, stop, id, payload)
      @resolving = false
      if payload[:exception]
        @error_on_resolve = true
        return
      end

      num_results = payload[:results].length
      klasses = payload[:results].map(&:class).map(&:name).uniq
      color = num_results == 0 ? :yellow : :green
      stmt = "#{indent}   #{num_results} #{"result".pluralize(num_results)}"
      stmt << " of #{"type".pluralize(klasses.length)} #{klasses.to_sentence}" if num_results > 0
      add_chunk(stmt, color, true)

      took = ((stop - start) * 1000.0).round(2)
      add_chunk("#{indent}   Took: #{took}ms", :magenta, true)
    end

    def on_schema_before_execute(name, start, stop, id, payload)
      Graphiti.debug(payload[:query].strip_heredoc, :white, true)
      unless payload[:variables].empty?
        Graphiti.debug("✨ Variables: #{payload[:variables].inspect}", :yellow, true)
      end
      unless payload[:context].empty?
        Graphiti.debug("✨ Context: #{payload[:context].inspect}", :blue, true)
      end
      Graphiti.debug(%|💡 Debug tip! Override Resource#resolve:

class YourResource < ApplicationResource
  # ... code ...
  def resolve(scope)
    debugger
    # if activerecord, call scope.to_sql/scope.to_a
    super
  end
end|, :white, true)
      Graphiti.debug("🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠 Executing! 🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠🚀🤠", :white, true)
    end

    def on_schema_execute(name, start, stop, id, payload)
      if payload[:exception] || (response_errors = payload[:result]["errors"])
        indent = indent(path: @last_association_path)
        add_chunk("#{indent}❌🚨❌🚨❌🚨❌ ERROR! ❌🚨❌🚨❌🚨❌", :red, true, path: @last_association_path)
        if @error_on_resolve
          add_chunk("#{indent}This error occurred while executing the above query, so it's likely not caused by Graphiti itself. Maybe bad SQL? Try running again and putting a debugger in this Resource's #resolve, or try to run the query independent of Graphiti/GraphQL.",
            :red, true, path: @last_association_path)
        end
        flush_chunks(@chunks)
        if response_errors
          Graphiti.info("❌🚨 Response contained errors!", :red, true)
          response_errors.each do |err|
            Graphiti.info("#{err['extensions']['code']} - #{err['message']}", :red, true)
            Graphiti.info("#{err['path'].join(".")}", :red, false) if err['path']
          end
        end
      else
        flush_chunks(@chunks)
        took = ((stop - start) * 1000.0).round(2)
        Graphiti.info("✅ Completed successfully in #{took}ms", :magenta, true)
      end
    end

    def on_resource_all(name, start, stop, id, payload)
      @resolving = true
      params = payload[:params].inspect
      resource = payload[:resource].name
      if thin_path.length == 1
        add_chunk("Query.#{thin_path.first}", :yellow, true)
      end
      add_chunk("#{indent}\\_ #{resource}.all(#{params})", :cyan, true)
    end

    def on_association(name, start, stop, id, payload)
      @last_association_path = thin_path
      sideload = payload[:sideload]
      add_chunk("#{indent}🔗 #{sideload.type} :#{sideload.name}", :white, true)
    end

    def on_before_stats(name, start, stop, id, payload)
      @stats = true
      add_chunk("#{indent}🔢 Calculating Statistics...", :yellow, true)
    end

    def on_after_stats(name, start, stop, id, payload)
      @stats = false
      took = ((stop - start) * 1000.0).round(2)
      add_chunk("#{indent}🔢 Done! Took #{took}ms", :yellow, true)
    end

    def on_activerecord(name, start, stop, id, payload)
      if @resolving || @stats
        sql = payload[:sql]
        unless sql.starts_with?('SHOW ')
          add_chunk("#{indent}#{sql}", :blue, true)
        end
      end
    end

    private

    def flush_chunks(chunks)
      chunks.each_pair do |_, value|
        value[:lines].each do |line|
          Graphiti.info(line[:text], line[:color], line[:bold])
        end
        flush_chunks(value.except(:lines))
      end
    end

    def add_chunk(text, color, bold, path: nil)
      path ||= thin_path
      current_chunks = @chunks
      path.each_with_index do |subpath, index|
        last = index == path.length - 1
        line = { text: text, color: color, bold: bold }
        if current_chunks.key?(subpath)
          if last
            current_chunks[subpath][:lines] << line
          else
            current_chunks = current_chunks[subpath]
          end
        else
          current_chunks[subpath] ||= { lines: [] }
          current_chunks[subpath][:lines] << line
        end
      end
    end

    def thin_path
      path = Graphiti.context[:object][:current_path]
      return [] unless path
      path.reject do |p|
        p.is_a?(Integer) ||
          p == "nodes" ||
          p == "node" ||
          p == "edges"
      end
    end

    def indent(path: nil)
      path ||= thin_path
      "   " * [path.length - 1, 0].max
    end

    def current_path
      path = Graphiti.context[:object][:current_path].join(".")
      "Query.#{path}"
    end
  end
end
