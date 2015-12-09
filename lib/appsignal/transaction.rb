module Appsignal
  class Transaction
    HTTP_REQUEST   = 'http_request'.freeze
    BACKGROUND_JOB = 'background_job'.freeze
    FRONTEND       = 'frontend'.freeze

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
      def create(id, namespace, request, options={})
        Thread.current[:appsignal_transaction] = Appsignal::Transaction.new(id, namespace, request, options)
      end

      def current
        Thread.current[:appsignal_transaction]
      end

      def complete_current!
        if current
          current.complete
          Thread.current[:appsignal_transaction] = nil
        else
          Appsignal.logger.error('Trying to complete current, but no transaction present')
        end
      end
    end

    attr_reader :transaction_index, :transaction_id, :namespace, :request, :paused, :tags, :options

    def initialize(transaction_id, namespace, request, options)
      @transaction_id = transaction_id
      @namespace = namespace
      @request = request
      @paused = false
      @tags = {}

      @options = options
      @options[:params_method] ||= :params

      @transaction_index = Appsignal::Extension.start_transaction(@transaction_id, @namespace)
    end

    def complete
      if Appsignal::Extension.finish_transaction(transaction_index)
        sample_data
      end
      Appsignal::Extension.complete_transaction(transaction_index)
    end

    def pause!
      @paused = true
    end

    def resume!
      @paused = false
    end

    def paused?
      @paused == true
    end

    def set_tags(given_tags={})
      @tags.merge!(given_tags)
    end

    def set_action(action)
      return unless action
      Appsignal::Extension.set_transaction_action(transaction_index, action)
    end

    def set_http_or_background_action(from=request.params)
      return unless from
      group_and_action = [
        from[:controller] || from[:class],
        from[:action] || from[:method]
      ]
      set_action(group_and_action.compact.join('#'))
    end

    def set_queue_start(start)
      return unless start
      Appsignal::Extension.set_transaction_queue_start(transaction_index, start)
    end

    def set_http_or_background_queue_start
      if namespace == HTTP_REQUEST
        set_queue_start(http_queue_start)
      elsif namespace == BACKGROUND_JOB
        set_queue_start(background_queue_start)
      end
    end

    def set_metadata(key, value)
      return unless key && value
      Appsignal::Extension.set_transaction_metadata(transaction_index, key, value)
    end

    def set_sample_data(key, data)
      return unless key && data && (data.is_a?(Array) || data.is_a?(Hash))
      Appsignal::Extension.set_transaction_sample_data(
        transaction_index,
        key.to_s,
        JSON.generate(data)
      )
    rescue JSON::GeneratorError=>e
      Appsignal.logger.error("JSON generate error (#{e.message}) for '#{data.inspect}'")
    end

    def sample_data
      {
        :params       => sanitized_params,
        :environment  => sanitized_environment,
        :session_data => sanitized_session_data,
        :tags         => sanitized_tags
      }.each do |key, data|
        set_sample_data(key, data)
      end
    end

    def set_error(error)
      return unless error
      return if Appsignal.is_ignored_error?(error)

      Appsignal.logger.debug("Adding #{error.class.name} to transaction: #{transaction_id}")
      backtrace = cleaned_backtrace(error.backtrace)
      Appsignal::Extension.set_transaction_error(
        transaction_index,
        error.class.name,
        error.message,
        backtrace ? JSON.generate(backtrace) : ''
      )
    rescue JSON::GeneratorError=>e
      Appsignal.logger.error("JSON generate error (#{e.message}) for '#{backtrace.inspect}'")
    end
    alias_method :add_exception, :set_error

    class GenericRequest
      attr_reader :env

      def initialize(env)
        @env = env
      end

      def params
        env[:params]
      end
    end

    protected

    def background_queue_start
      return unless request.env
      return unless queue_start = request.env[:queue_start]
      (queue_start.to_f * 1000.0).to_i
    end

    def http_queue_start
      return unless request.env
      return unless env_var = request.env['HTTP_X_QUEUE_START'.freeze] || request.env['HTTP_X_REQUEST_START'.freeze]
      cleaned_value = env_var.tr('^0-9'.freeze, ''.freeze)
      return if cleaned_value.empty?
      value = cleaned_value.to_i
      if value > 4_102_441_200_000
        # Value is in microseconds
        value / 1_000
      elsif value < 946_681_200_000
        # Value is to low to be plausible
        nil
      else
        # Value is in milliseconds
        value
      end
    end

    def sanitized_params
      return unless Appsignal.config[:send_params]
      return unless request.respond_to?(options[:params_method])
      return unless params = request.send(options[:params_method])
      if params.is_a?(Hash)
        Appsignal::ParamsSanitizer.sanitize(params)
      elsif params.is_a?(Array)
        params
      end
    end

    def sanitized_environment
      return unless request.env
      {}.tap do |out|
        ENV_METHODS.each do |key|
          out[key] = request.env[key] if request.env[key]
        end
      end
    end

    def sanitized_session_data
      return if Appsignal.config[:skip_session_data] || !request.respond_to?(:session)
      return unless session = request.session
      Appsignal::ParamsSanitizer.sanitize(session.to_hash)
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
      if defined?(::Rails) && backtrace
        ::Rails.backtrace_cleaner.clean(backtrace, nil)
      else
        backtrace
      end
    end
  end
end
