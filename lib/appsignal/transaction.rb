 module Appsignal
  class Transaction
    # Based on what Rails uses + some variables we'd like to show
    ENV_METHODS = %w(CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER REMOTE_ADDR
    REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL

    HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
    HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME HTTP_X_APPLICATION_START
    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
    HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE
    HTTP_PRAGMA HTTP_REFERER HTTP_X_FORWARDED_FOR).freeze

    def self.create(key, env)
      Appsignal.logger.debug("Creating transaction: #{key}")
      Thread.current[:appsignal_transaction_id] = key
      Appsignal.transactions[key] = Appsignal::Transaction.new(key, env)
    end

    def self.current
      Appsignal.transactions[Thread.current[:appsignal_transaction_id]]
    end

    attr_reader :request_id, :events, :process_action_event, :action, :exception,
                :env, :fullpath, :time, :tags, :kind, :queue_start

    def initialize(request_id, env)
      @request_id = request_id
      @events = []
      @process_action_event = nil
      @exception = nil
      @env = env
      @tags = {}
    end

    def sanitized_environment
      @sanitized_environment ||= {}
    end

    def sanitized_session_data
      @sanitized_session_data ||= {}
    end

    def request
      ::Rack::Request.new(@env)
    end

    def set_tags(given_tags={})
      @tags.merge!(given_tags)
    end

    def set_process_action_event(event)
      @process_action_event = event
      return unless event && event.payload
      @action = "#{event.payload[:controller]}##{event.payload[:action]}"
      @kind = 'http_request'
      set_http_queue_start
    end

    def set_perform_job_event(event)
      @process_action_event = event
      return unless event && event.payload
      @action = "#{event.payload[:class]}##{event.payload[:method]}"
      @kind = 'background_job'
      set_background_queue_start
    end

    def add_event(event)
      @events << event
    end

    def add_exception(ex)
      @time = Time.now.utc.to_f
      @exception = ex
    end

    def exception?
      !!exception
    end

    def slow_request?
      return false unless process_action_event && process_action_event.payload
      Appsignal.config[:slow_request_threshold] <= process_action_event.duration
    end

    def slower?(transaction)
      process_action_event.duration > transaction.process_action_event.duration
    end

    def truncate!
      process_action_event.payload.clear
      events.clear
      tags.clear
      sanitized_environment.clear
      sanitized_session_data.clear
      @env = nil
    end

    def convert_values_to_primitives!
      Appsignal::Transaction::ParamsSanitizer.sanitize!(@process_action_event.payload) if @process_action_event
      @events.each { |o| Appsignal::Transaction::ParamsSanitizer.sanitize!(o.payload) }
      add_sanitized_context!
    end

    def type
      return :exception if exception?
      return :slow_request if slow_request?
      :regular_request
    end

    def to_hash
      Formatter.new(self).to_hash
    end

    def complete!
      Appsignal.logger.debug("Completing transaction: #{@request_id}")
      Thread.current[:appsignal_transaction_id] = nil
      current_transaction = Appsignal.transactions.delete(@request_id)
      if process_action_event || exception?
        if Appsignal::Pipe.current
          Appsignal::Pipe.current.write(self)
        else
          Appsignal.enqueue(current_transaction)
        end
      else
        Appsignal.logger.debug("No process_action_event or exception: #{@request_id}")
      end
    end

    def set_background_queue_start
      queue_start = process_action_event.payload[:queue_start]
      return unless queue_start
      Appsignal.logger.debug("Setting background queue start: #{queue_start}")
      @queue_start = queue_start.to_f
    end

    def set_http_queue_start
      return unless env
      env_var = env['HTTP_X_QUEUE_START'] || env['HTTP_X_REQUEST_START']
      if env_var
        Appsignal.logger.debug("Setting http queue start: #{env_var}")
        value = env_var.tr('^0-9', '')
        unless value.empty?
          @queue_start = value.to_f / 1000.0
        end
      end
    end

    protected

    def add_sanitized_context!
      sanitize_environment!
      sanitize_session_data! if kind == 'http_request'
      sanitize_tags!
      @env = nil
    end

    # Only keep tags if they meet the following criteria:
    # * Key is a symbol or string with less then 100 chars
    # * Value is a symbol or string with less then 100 chars
    # * Value is an integer
    def sanitize_tags!
      @tags.keep_if do |k,v|
        (k.is_a?(Symbol) || k.is_a?(String) && k.length <= 100) &&
        (((v.is_a?(Symbol) || v.is_a?(String)) && v.length <= 100) || (v.is_a?(Integer)))
      end
    end

    def sanitize_environment!
      env.each do |key, value|
        sanitized_environment[key] = value if ENV_METHODS.include?(key)
      end
    end

    def sanitize_session_data!
      @sanitized_session_data = Appsignal::Transaction::ParamsSanitizer.sanitize(
        request.session.to_hash
      )
      @fullpath = request.fullpath
    end
  end
end
