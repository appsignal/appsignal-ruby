# frozen_string_literal: true

require "json"

module Appsignal
  class Transaction
    HTTP_REQUEST   = "http_request"
    BACKGROUND_JOB = "background_job"
    ACTION_CABLE   = "action_cable"
    FRONTEND       = "frontend"
    BLANK          = ""
    ALLOWED_TAG_KEY_TYPES = [Symbol, String].freeze
    ALLOWED_TAG_VALUE_TYPES = [Symbol, String, Integer].freeze
    BREADCRUMB_LIMIT = 20

    class << self
      def create(id, namespace, request, options = {})
        # Allow middleware to force a new transaction
        Thread.current[:appsignal_transaction] = nil if options.include?(:force) && options[:force]

        # Check if we already have a running transaction
        if Thread.current[:appsignal_transaction].nil?
          # If not, start a new transaction
          Thread.current[:appsignal_transaction] =
            Appsignal::Transaction.new(id, namespace, request, options)
        else
          # Otherwise, log the issue about trying to start another transaction
          Appsignal.logger.warn_once_then_debug(
            :transaction_id,
            "Trying to start new transaction with id " \
              "'#{id}', but a transaction with id '#{current.transaction_id}' " \
              "is already running. Using transaction '#{current.transaction_id}'."
          )

          # And return the current transaction instead
          current
        end
      end

      # Returns currently active transaction or a {NilTransaction} if none is
      # active.
      #
      # @see .current?
      # @return [Boolean]
      def current
        Thread.current[:appsignal_transaction] || NilTransaction.new
      end

      # Returns if any transaction is currently active or not. A
      # {NilTransaction} is not considered an active transaction.
      #
      # @see .current
      # @return [Boolean]
      def current?
        current && !current.nil_transaction?
      end

      def complete_current!
        current.complete
      rescue => e
        Appsignal.logger.error(
          "Failed to complete transaction ##{current.transaction_id}. #{e.message}"
        )
      ensure
        clear_current_transaction!
      end

      # Remove current transaction from current Thread.
      # @api private
      def clear_current_transaction!
        Thread.current[:appsignal_transaction] = nil
      end
    end

    attr_reader :ext, :transaction_id, :action, :namespace, :request, :paused, :tags, :options,
      :discarded, :breadcrumbs

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
      @breadcrumbs = []
      @store = Hash.new({})
      @options = options
      @options[:params_method] ||= :params

      @ext = Appsignal::Extension.start_transaction(
        @transaction_id,
        @namespace,
        0
      ) || Appsignal::Extension::MockTransaction.new
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
      sample_data if @ext.finish(0)
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
    # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    def set_tags(given_tags = {})
      @tags.merge!(given_tags)
    end

    # Add breadcrumbs to the transaction.
    #
    # @param category [String] category of breadcrumb
    #   e.g. "UI", "Network", "Navigation", "Console".
    # @param action [String] name of breadcrumb
    #   e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
    # @option message [String]  optional message in string format
    # @option metadata [Hash<String,String>]  key/value metadata in <string, string> format
    # @option time [Time] time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
    # @return [void]
    #
    # @see Appsignal.add_breadcrumb
    # @see https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html
    #   Breadcrumb reference
    def add_breadcrumb(category, action, message = "", metadata = {}, time = Time.now.utc)
      @breadcrumbs.push(
        :time => time.to_i,
        :category => category,
        :action => action,
        :message => message,
        :metadata => metadata
      )
      @breadcrumbs = @breadcrumbs.last(BREADCRUMB_LIMIT)
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
    #   transaction.set_namespace("background")
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
      set_action_if_nil(group_and_action.compact.join("#"))
    end

    # Set queue start time for transaction.
    #
    # Most commononly called by {set_http_or_background_queue_start}.
    #
    # @param start [Integer] Queue start time in milliseconds.
    # @raise [RangeError] When the queue start time value is too big, this
    #   method raises a RangeError.
    # @raise [TypeError] Raises a TypeError when the given `start` argument is
    #   not an Integer.
    # @return [void]
    def set_queue_start(start)
      return unless start

      @ext.set_queue_start(start)
    rescue RangeError
      Appsignal.logger.warn("Queue start value #{start} is too big")
    end

    # Set the queue time based on the HTTP header or `:queue_start` env key
    # value.
    #
    # This method will first try to read the queue time from the HTTP headers
    # `X-Request-Start` or `X-Queue-Start`. Which are parsed by Rack as
    # `HTTP_X_QUEUE_START` and `HTTP_X_REQUEST_START`.
    # The header value is parsed by AppSignal as either milliseconds or
    # microseconds.
    #
    # If no headers are found, or the value could not be parsed, it falls back
    # on the `:queue_start` env key on this Transaction's {request} environment
    # (called like `request.env[:queue_start]`). This value is parsed by
    # AppSignal as seconds.
    #
    # @see https://docs.appsignal.com/ruby/instrumentation/request-queue-time.html
    # @return [void]
    def set_http_or_background_queue_start
      start = http_queue_start || background_queue_start
      return unless start

      set_queue_start(start)
    end

    def set_metadata(key, value)
      return unless key && value

      @ext.set_metadata(key, value)
    end

    def set_sample_data(key, data)
      return unless key && data && (data.is_a?(Array) || data.is_a?(Hash))

      @ext.set_sample_data(
        key.to_s,
        Appsignal::Utils::Data.generate(data)
      )
    rescue RuntimeError => e
      begin
        inspected_data = data.inspect
        Appsignal.logger.error(
          "Error generating data (#{e.class}: #{e.message}) for '#{inspected_data}'"
        )
      rescue => e
        Appsignal.logger.error(
          "Error generating data (#{e.class}: #{e.message}). Can't inspect data."
        )
      end
    end

    def sample_data
      {
        :params => sanitized_params,
        :environment => sanitized_environment,
        :session_data => sanitized_session_data,
        :metadata => metadata,
        :tags => sanitized_tags,
        :breadcrumbs => breadcrumbs
      }.each do |key, data|
        set_sample_data(key, data)
      end
    end

    def set_error(error)
      unless error.is_a?(Exception)
        Appsignal.logger.error "Appsignal::Transaction#set_error: Cannot set error. " \
          "The given value is not an exception: #{error.inspect}"
        return
      end
      return unless error
      return unless Appsignal.active?

      backtrace = cleaned_backtrace(error.backtrace)
      @ext.set_error(
        error.class.name,
        cleaned_error_message(error),
        backtrace ? Appsignal::Utils::Data.generate(backtrace) : Appsignal::Extension.data_array_new
      )
    end
    alias_method :add_exception, :set_error

    def start_event
      return if paused?

      @ext.start_event(0)
    end

    def finish_event(name, title, body, body_format = Appsignal::EventFormatter::DEFAULT)
      return if paused?

      @ext.finish_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT,
        0
      )
    end

    def record_event(name, title, body, duration, body_format = Appsignal::EventFormatter::DEFAULT)
      return if paused?

      @ext.record_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT,
        duration,
        0
      )
    end

    def instrument(name, title = nil, body = nil, body_format = Appsignal::EventFormatter::DEFAULT)
      start_event
      yield if block_given?
    ensure
      finish_event(name, title, body, body_format)
    end

    # @api private
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
    # @return [Integer] `:queue_start` time (in seconds) converted to milliseconds
    def background_queue_start
      env = environment
      return unless env

      queue_start = env[:queue_start]
      return unless queue_start

      (queue_start.to_f * 1000.0).to_i # Convert seconds to milliseconds
    end

    # Returns HTTP queue start time in milliseconds.
    #
    # @return [nil] if no queue start time is found.
    # @return [nil] if begin time is too low to be plausible.
    # @return [Integer] queue start in milliseconds.
    def http_queue_start
      env = environment
      return unless env

      env_var = env["HTTP_X_QUEUE_START"] || env["HTTP_X_REQUEST_START"]
      return unless env_var

      cleaned_value = env_var.tr("^0-9", "")
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

      filter_keys = Appsignal.config[:filter_parameters] || []
      Appsignal::Utils::HashSanitizer.sanitize params, filter_keys
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
    # @return [nil] if no environment is present.
    # @return [Hash<String, Object>]
    def sanitized_environment
      env = environment
      return if env.empty?

      {}.tap do |out|
        Appsignal.config[:request_headers].each do |key|
          out[key] = env[key] if env[key]
        end
      end
    end

    # Returns sanitized session data.
    #
    # The session data is sanitized by the {Appsignal::Utils::HashSanitizer}.
    #
    # @return [nil] if `:send_session_data` config is set to `false`.
    # @return [nil] if the {#request} object doesn't respond to `#session`.
    # @return [nil] if the {#request} session data is `nil`.
    # @return [Hash<String, Object>]
    def sanitized_session_data
      return if !Appsignal.config[:send_session_data] ||
        !request.respond_to?(:session)

      session = request.session
      return unless session

      Appsignal::Utils::HashSanitizer.sanitize(
        session.to_hash, Appsignal.config[:filter_session_data]
      )
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
    #
    # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
    def sanitized_tags
      @tags.select do |key, value|
        ALLOWED_TAG_KEY_TYPES.any? { |type| key.is_a? type } &&
          ALLOWED_TAG_VALUE_TYPES.any? { |type| value.is_a? type }
      end
    end

    def cleaned_backtrace(backtrace)
      if defined?(::Rails) && Rails.respond_to?(:backtrace_cleaner) && backtrace
        ::Rails.backtrace_cleaner.clean(backtrace, nil)
      else
        backtrace
      end
    end

    # Clean error messages that are known to potentially contain user data.
    # Returns an unchanged message otherwise.
    def cleaned_error_message(error)
      case error.class.to_s
      when "PG::UniqueViolation", "ActiveRecord::RecordNotUnique"
        error.message.to_s.gsub(/\)=\(.*\)/, ")=(?)")
      else
        error.message.to_s
      end
    end

    # Stub that is returned by {Transaction.current} if there is no current
    # transaction, so that it's still safe to call methods on it if there is no
    # current transaction.
    class NilTransaction
      def method_missing(_method, *args, &block)
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
