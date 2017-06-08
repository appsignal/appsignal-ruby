require "json"

module Appsignal
  class Transaction
    HTTP_REQUEST   = "http_request".freeze
    BACKGROUND_JOB = "background_job".freeze
    ACTION_CABLE   = "action_cable".freeze
    FRONTEND       = "frontend".freeze
    BLANK          = "".freeze

    # Based on what Rails uses + some variables we'd like to show
    ENV_METHODS = %w(
      CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
      PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER REMOTE_ADDR
      REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL REQUEST_URI
      PATH_INFO

      HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
      HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME HTTP_X_APPLICATION_START
      HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
      HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM
      HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_X_FORWARDED_FOR
      HTTP_CLIENT_IP HTTP_RANGE HTTP_X_AUTH_TOKEN
    ).freeze

    class << self
      def create(id, namespace, request, options = {})
        # Allow middleware to force a new transaction
        if options.include?(:force) && options[:force]
          Thread.current[:appsignal_transaction] = nil
        end

        # Check if we already have a running transaction
        if Thread.current[:appsignal_transaction] != nil
          # Log the issue and return the current transaction
          Appsignal.logger.debug "Trying to start new transaction with id " \
            "'#{id}', but a transaction with id '#{current.transaction_id}' " \
            "is already running. Using transaction '#{current.transaction_id}'."

          # Return the current (running) transaction
          current
        else
          # Otherwise, start a new transaction
          Thread.current[:appsignal_transaction] = Appsignal::Transaction.new(id, namespace, request, options)
        end
      end

      def current
        Thread.current[:appsignal_transaction] || NilTransaction.new
      end

      def complete_current!
        current.complete
      rescue => e
        Appsignal.logger.error("Failed to complete transaction ##{current.transaction_id}. #{e.message}")
      ensure
        Thread.current[:appsignal_transaction] = nil
      end

      def garbage_collection_profiler
        @garbage_collection_profiler ||= Appsignal::GarbageCollectionProfiler.new
      end
    end

    attr_reader :ext, :transaction_id, :action, :namespace, :request, :paused, :tags, :options, :discarded

    # @!attribute params
    #   Attribute for parameters of the transaction.
    #
    #   When no parameters are set with {#params=} the parameters it will look
    #   for parameters on the {#request} environment.
    #
    #   The parameters set using {#params=} are leading over those extracted
    #   from a request's environment.
    #
    #   @return [Hash]
    attr_writer :params

    def initialize(transaction_id, namespace, request, options = {})
      @transaction_id = transaction_id
      @action = nil
      @namespace = namespace
      @request = request
      @paused = false
      @discarded = false
      @tags = {}
      @store = Hash.new({})
      @options = options
      @options[:params_method] ||= :params

      @ext = Appsignal::Extension.start_transaction(
        @transaction_id,
        @namespace,
        self.class.garbage_collection_profiler.total_time
      )
    end

    def nil_transaction?
      false
    end

    def complete
      if discarded?
        Appsignal.logger.debug "Skipping transaction '#{transaction_id}' " \
          "because it was manually discarded."
        return
      end
      if @ext.finish(self.class.garbage_collection_profiler.total_time)
        sample_data
      end
      @ext.complete
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

    def discard!
      @discarded = true
    end

    def restore!
      @discarded = false
    end

    def discarded?
      @discarded == true
    end

    def store(key)
      @store[key]
    end

    def params
      return @params if defined?(@params)
      request_params
    end

    # Set tags on the transaction.
    #
    # @param given_tags [Hash] Collection of tags.
    # @option given_tags [String, Symbol, Integer] :any
    #   The name of the tag as a Symbol.
    # @option given_tags [String, Symbol, Integer] "any"
    #   The name of the tag as a String.
    # @return [void]
    #
    # @see Appsignal.tag_request
    # @see http://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    def set_tags(given_tags = {})
      @tags.merge!(given_tags)
    end

    # Set an action name for the transaction.
    #
    # An action name is used to identify the location of a certain sample;
    # error and performance issues.
    #
    # @param action [String] the action name to set.
    # @return [void]
    # @see Appsignal.set_action
    # @see #set_action_if_nil
    # @since 2.2.0
    def set_action(action)
      return unless action
      @action = action
      @ext.set_action(action)
    end

    # Set an action name only if there is no current action set.
    #
    # Commonly used by AppSignal integrations so that they don't override
    # custom action names.
    #
    # @example
    #   Appsignal.set_action("foo")
    #   Appsignal.set_action_if_nil("bar")
    #   # Transaction action will be "foo"
    #
    # @param action [String]
    # @return [void]
    # @see #set_action
    # @since 2.2.0
    def set_action_if_nil(action)
      return if @action
      set_action(action)
    end

    # Set the namespace for this transaction.
    #
    # Useful to split up parts of an application into certain namespaces. For
    # example: http requests, background jobs and administration panel
    # controllers.
    #
    # Note: The "http_request" namespace gets transformed on AppSignal.com to
    # "Web" and "background_job" gets transformed to "Background".
    #
    # @example
    #   transaction.set_action("admin")
    #
    # @param namespace [String] namespace name to use for this transaction.
    # @return [void]
    # @since 2.2.0
    def set_namespace(namespace)
      return unless namespace
      @namespace = namespace
      @ext.set_namespace(namespace)
    end

    def set_http_or_background_action(from = request.params)
      return unless from
      group_and_action = [
        from[:controller] || from[:class],
        from[:action] || from[:method]
      ]
      set_action(group_and_action.compact.join("#"))
    end

    def set_queue_start(start)
      return unless start
      @ext.set_queue_start(start)
    rescue RangeError
      Appsignal.logger.warn("Queue start value #{start} is too big")
    end

    def set_http_or_background_queue_start
      if namespace == HTTP_REQUEST
        set_queue_start(http_queue_start)
      elsif namespace == BACKGROUND_JOB
        set_queue_start(background_queue_start)
      end
    end

    def set_params(params)
      @params = params
    end

    def set_metadata(key, value)
      return unless key && value
      @ext.set_metadata(key, value)
    end

    def set_sample_data(key, data)
      return unless key && data && (data.is_a?(Array) || data.is_a?(Hash))
      @ext.set_sample_data(
        key.to_s,
        Appsignal::Utils.data_generate(data)
      )
    rescue RuntimeError => e
      Appsignal.logger.error("Error generating data (#{e.class}: #{e.message}) for '#{data.inspect}'")
    end

    def sample_data
      {
        :params       => sanitized_params,
        :environment  => sanitized_environment,
        :session_data => sanitized_session_data,
        :metadata     => metadata,
        :tags         => sanitized_tags
      }.each do |key, data|
        set_sample_data(key, data)
      end
    end

    def set_error(error)
      return unless error
      return unless Appsignal.active?

      backtrace = cleaned_backtrace(error.backtrace)
      @ext.set_error(
        error.class.name,
        error.message.to_s,
        backtrace ? Appsignal::Utils.data_generate(backtrace) : Appsignal::Extension.data_array_new
      )
    end
    alias_method :add_exception, :set_error

    def start_event
      @ext.start_event(self.class.garbage_collection_profiler.total_time)
    end

    def finish_event(name, title, body, body_format = Appsignal::EventFormatter::DEFAULT)
      @ext.finish_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT,
        self.class.garbage_collection_profiler.total_time
      )
    end

    def record_event(name, title, body, duration, body_format = Appsignal::EventFormatter::DEFAULT)
      @ext.record_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT,
        duration,
        self.class.garbage_collection_profiler.total_time
      )
    end

    def instrument(name, title = nil, body = nil, body_format = Appsignal::EventFormatter::DEFAULT)
      start_event
      yield if block_given?
    ensure
      finish_event(name, title, body, body_format)
    end

    def to_h
      JSON.parse(@ext.to_json)
    end
    alias_method :to_hash, :to_h

    class GenericRequest
      attr_reader :env

      def initialize(env)
        @env = env
      end

      def params
        env[:params]
      end
    end

    private

    # Returns calculated background queue start time in milliseconds, based on
    # environment values.
    #
    # @return [nil] if no {#environment} is present.
    # @return [nil] if there is no `:queue_start` in the {#environment}.
    # @return [Integer]
    def background_queue_start
      env = environment
      return unless env
      queue_start = env[:queue_start]
      return unless queue_start

      (queue_start.to_f * 1000.0).to_i
    end

    # Returns HTTP queue start time in milliseconds.
    #
    # @return [nil] if no queue start time is found.
    # @return [nil] if begin time is too low to be plausible.
    # @return [Integer] queue start in milliseconds.
    def http_queue_start
      env = environment
      return unless env
      env_var = env["HTTP_X_QUEUE_START".freeze] || env["HTTP_X_REQUEST_START".freeze]
      return unless env_var
      cleaned_value = env_var.tr("^0-9".freeze, "".freeze)
      return if cleaned_value.empty?

      value = cleaned_value.to_i
      if value > 4_102_441_200_000
        # Value is in microseconds. Transform to milliseconds.
        value / 1_000
      elsif value < 946_681_200_000
        # Value is too low to be plausible
        nil
      else
        # Value is in milliseconds
        value
      end
    end

    def sanitized_params
      return unless Appsignal.config[:send_params]

      Appsignal::Utils::ParamsSanitizer.sanitize params, sanitize_parameters_options
    end

    def fetch_params_from_request
      return unless request.respond_to?(options[:params_method])

      begin
        request.send options[:params_method]
      rescue => e
        # Getting params from the request has been know to fail.
        Appsignal.logger.debug "Exception while getting params: #{e}"
        nil
      end
    end

    def sanitize_parameters_options
      {}.tap do |options|
        if Appsignal.config[:filter_parameters]
          options[:filter_parameters] = Appsignal.config[:filter_parameters]
        end
      end
    end

    def request_params
      return unless request.respond_to?(options[:params_method])

      begin
        request.send options[:params_method]
      rescue => e
        # Getting params from the request has been know to fail.
        Appsignal.logger.debug "Exception while getting params: #{e}"
        nil
      end
    end

    # Returns sanitized environment for a transaction.
    #
    # The environment of a transaction can contain a lot of information, not
    # all of it useful for debugging.
    #
    # Only the values from the keys specified in {ENV_METHODS} are returned.
    #
    # @return [nil] if no environment is present.
    # @return [Hash<String, Object>]
    def sanitized_environment
      env = environment
      return if env.empty?

      {}.tap do |out|
        ENV_METHODS.each do |key|
          out[key] = env[key] if env[key]
        end
      end
    end

    # Returns sanitized session data.
    #
    # The session data is sanitized by the {Appsignal::Utils::ParamsSanitizer}.
    #
    # @return [nil] if `:skip_session_data` config is set to `true`.
    # @return [nil] if the {#request} object doesn't respond to `#session`.
    # @return [nil] if the {#request} session data is `nil`.
    # @return [Hash<String, Object>]
    def sanitized_session_data
      return if Appsignal.config[:skip_session_data] ||
          !request.respond_to?(:session)
      session = request.session
      return unless session

      Appsignal::Utils::ParamsSanitizer.sanitize(session.to_hash)
    end

    # Returns metadata from the environment.
    #
    # @return [nil] if no `:metadata` key is present in the {#environment}.
    # @return [Hash<String, Object>]
    def metadata
      environment[:metadata]
    end

    # Returns the environment for a transaction.
    #
    # Returns an empty Hash when the {#request} object doesn't listen to the
    # `#env` method or the `#env` is nil.
    #
    # @return [Hash<String, Object>]
    def environment
      return {} unless request.respond_to?(:env)
      return {} unless request.env

      request.env
    end

    # Only keep tags if they meet the following criteria:
    # * Key is a symbol or string with less then 100 chars
    # * Value is a symbol or string with less then 100 chars
    # * Value is an integer
    def sanitized_tags
      @tags.select do |k, v|
        (k.is_a?(Symbol) || k.is_a?(String) && k.length <= 100) &&
          (((v.is_a?(Symbol) || v.is_a?(String)) && v.length <= 100) || v.is_a?(Integer))
      end
    end

    def cleaned_backtrace(backtrace)
      if defined?(::Rails) && backtrace
        ::Rails.backtrace_cleaner.clean(backtrace, nil)
      else
        backtrace
      end
    end

    # Stub that is returned by {Transaction.current} if there is no current
    # transaction, so that it's still safe to call methods on it if there is no
    # current transaction.
    class NilTransaction
      def method_missing(m, *args, &block)
      end

      # Instrument should still yield
      def instrument(*_args)
        yield
      end

      def nil_transaction?
        true
      end
    end
  end
end
