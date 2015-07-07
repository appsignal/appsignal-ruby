module Appsignal
  class Transaction
    HTTP_REQUEST   = 'http_request'.freeze
    BACKGROUND_JOB = 'background_job'.freeze

    # Based on what Rails uses + some variables we'd like to show
    ENV_METHODS = %w(CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER REMOTE_ADDR
    REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL REQUEST_URI PATH_INFO

    HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
    HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME HTTP_X_APPLICATION_START
    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
    HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE
    HTTP_PRAGMA HTTP_REFERER HTTP_X_FORWARDED_FOR HTTP_CLIENT_IP).freeze

    class << self
      def create(request_id, env)
        Appsignal.logger.debug("Creating transaction: #{request_id}")
        Thread.current[:appsignal_transaction] = Appsignal::Transaction.new(request_id, env)
      end

      def current
        Thread.current[:appsignal_transaction]
      end

      def complete_current!
        if current
          Appsignal::Extension.finish_transaction(current.transaction_index)
          Thread.current[:appsignal_transaction] = nil
        else
          Appsignal.logger.error('Trying to complete current, but no transaction present')
        end
      end
    end

    attr_reader :request_id, :transaction_index, :process_action_event, :action, :exception,
                :env, :fullpath, :time, :tags, :kind, :queue_start, :paused, :root_event_payload

    def initialize(request_id, env)
      @root_event_payload = nil
      @request_id = request_id
      @process_action_event = nil
      @exception = nil
      @env = env
      @tags = {}
      @paused = false
      @queue_start = -1
      @transaction_index = Appsignal::Extension.start_transaction(@request_id)
    end

    def sanitized_environment
      @sanitized_environment ||= {}
    end

    def sanitized_session_data
      @sanitized_session_data ||= {}
    end

    def request
      @request ||= ::Rack::Request.new(env)
    end

    def set_tags(given_tags={})
      @tags.merge!(given_tags)
    end

    def set_root_event(name, payload)
      @root_event_payload = payload
      if name.start_with?(Subscriber::PROCESS_ACTION_PREFIX)
        @action = "#{@root_event_payload[:controller]}##{@root_event_payload[:action]}"
        @kind = HTTP_REQUEST
        set_http_queue_start
        set_metadata('path', payload[:path])
        set_metadata('request_format', payload[:request_format])
        set_metadata('request_method', payload[:request_method])
        set_metadata('status', payload[:status].to_s)
      elsif name.start_with?(Subscriber::PERFORM_JOB_PREFIX)
        @action = "#{@root_event_payload[:class]}##{@root_event_payload[:method]}"
        @kind = BACKGROUND_JOB
        set_background_queue_start
      end
      Appsignal::Extension.set_transaction_base_data(
        transaction_index,
        kind,
        action,
        queue_start
      )
    end

    def set_metadata(key, value)
      return unless value
      Appsignal::Extension.set_transaction_metadata(transaction_index, key, value)
    end

    def set_error(error)
      return unless error
      Appsignal.logger.debug("Adding #{error.class.name} to transaction: #{request_id}")
      Appsignal::Extension.set_transaction_error(
        transaction_index,
        error.class.name,
        error.message
      )

      {
        :params       => sanitized_params,
        :environment  => sanitized_environment,
        :session_data => sanitized_session_data,
        :backtrace    => cleaned_backtrace(error.backtrace),
        :tags         => sanitized_tags
      }.each do |key, data|
        next unless data.is_a?(Array) || data.is_a?(Hash)
        begin
          Appsignal::Extension.set_transaction_error_data(
            transaction_index,
            key.to_s,
            JSON.generate(data)
          )
        rescue JSON::GeneratorError=>e
          Appsignal.logger.error("JSON generate error (#{e.message}) for '#{data.inspect}'")
        end
      end
    end
    alias_method :add_exception, :set_error

    def pause!
      @paused = true
    end

    def resume!
      @paused = false
    end

    def paused?
      @paused == true
    end

    protected

    def set_background_queue_start
      return unless root_event_payload
      queue_start = root_event_payload[:queue_start]
      return unless queue_start
      Appsignal.logger.debug("Setting background queue start: #{queue_start}")
      @queue_start = (queue_start.to_f * 1000.0).to_i
    end

    def sanitized_params
      return unless root_event_payload
      Appsignal::ParamsSanitizer.sanitize(root_event_payload[:params])
    end

    def set_http_queue_start
      return unless env
      env_var = env['HTTP_X_QUEUE_START'] || env['HTTP_X_REQUEST_START']
      if env_var
        Appsignal.logger.debug("Setting http queue start: #{env_var}")
        cleaned_value = env_var.tr('^0-9', '')
        unless cleaned_value.empty?
          value = cleaned_value.to_i
          [1_000_000.0, 1_000.0].each do |factor|
            @queue_start = (value / factor).to_i
            break if @queue_start > 946_681_200.0 # Ok if it's later than 2000
          end
        end
      end
    end

    def sanitized_environment
      return unless env
      {}.tap do |out|
        ENV_METHODS.each do |key|
          out[key] = env[key] if env[key]
        end
      end
    end

    def sanitized_session_data
      return if Appsignal.config[:skip_session_data] || !env
      Appsignal::ParamsSanitizer.sanitize(request.session.to_hash)
    end

    # Only keep tags if they meet the following criteria:
    # * Key is a symbol or string with less then 100 chars
    # * Value is a symbol or string with less then 100 chars
    # * Value is an integer
    def sanitized_tags
      @tags.select do |k, v|
        (k.is_a?(Symbol) || k.is_a?(String) && k.length <= 100) &&
        (((v.is_a?(Symbol) || v.is_a?(String)) && v.length <= 100) || (v.is_a?(Integer)))
      end
    end

    def cleaned_backtrace(backtrace)
      if defined?(::Rails)
        ::Rails.backtrace_cleaner.clean(backtrace, nil)
      else
        backtrace
      end
    end

  end
end
