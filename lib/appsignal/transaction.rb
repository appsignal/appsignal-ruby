# frozen_string_literal: true

require "json"

module Appsignal
  class Transaction
    HTTP_REQUEST   = "http_request"
    BACKGROUND_JOB = "background_job"
    # @api private
    ACTION_CABLE   = "action_cable"
    # @api private
    FRONTEND       = "frontend"
    # @api private
    BLANK          = ""
    # @api private
    ALLOWED_TAG_KEY_TYPES = [Symbol, String].freeze
    # @api private
    ALLOWED_TAG_VALUE_TYPES = [Symbol, String, Integer, TrueClass, FalseClass].freeze
    # @api private
    BREADCRUMB_LIMIT = 20
    # @api private
    ERROR_CAUSES_LIMIT = 10
    ADDITIONAL_ERRORS_LIMIT = 10

    class << self
      # Create a new transaction and set it as the currently active
      # transaction.
      #
      # @param namespace [String] Namespace of the to be created transaction.
      # @return [Transaction]
      def create(namespace)
        # Check if we already have a running transaction
        if Thread.current[:appsignal_transaction].nil?
          # If not, start a new transaction
          Thread.current[:appsignal_transaction] =
            Appsignal::Transaction.new(
              SecureRandom.uuid,
              namespace
            )
        else
          # Otherwise, log the issue about trying to start another transaction
          Appsignal.internal_logger.warn(
            "Trying to start new transaction, but a transaction " \
              "with id '#{current.transaction_id}' is already running. " \
              "Using transaction '#{current.transaction_id}'."
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

      # Complete the currently active transaction and unset it as the active
      # transaction.
      def complete_current!
        current.complete
      rescue => e
        Appsignal.internal_logger.error(
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

    # @api private
    attr_reader :ext, :transaction_id, :action, :namespace, :request, :paused, :tags, :options,
      :breadcrumbs, :custom_data, :is_duplicate, :has_error, :errors

    # Use {.create} to create new transactions.
    #
    # @param transaction_id [String] ID of the to be created transaction.
    # @param namespace [String] Namespace of the to be created transaction.
    # @see create
    # @api private
    def initialize(transaction_id, namespace, ext: nil)
      @transaction_id = transaction_id
      @action = nil
      @namespace = namespace
      @paused = false
      @discarded = false
      @tags = {}
      @custom_data = nil
      @breadcrumbs = []
      @store = Hash.new({})
      @params = nil
      @session_data = nil
      @headers = nil
      @has_error = false
      @errors = []
      @is_duplicate = false

      @ext = ext || Appsignal::Extension.start_transaction(
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
        Appsignal.internal_logger.debug "Skipping transaction '#{transaction_id}' " \
          "because it was manually discarded."
        return
      end

      # If the transaction does not have a set error, take the last of
      # the additional errors, if one exists, and set it as the error
      # for this transaction. This ensures that we do not report both
      # a performance sample and a duplicate error sample.
      set_error(errors.pop) if !has_error && !errors.empty?

      # If the transaction is a duplicate, we don't want to finish it,
      # because we want its finish time to be the finish time of the
      # original transaction, and we do not want to set its sample
      # data, because it should keep the sample data it duplicated from
      # the original transaction.
      # On duplicate transactions, the value of the sample flag, which
      # is set on finish, will be duplicated from the original transaction.
      sample_data if !is_duplicate && ext.finish(0)

      errors.each do |error|
        duplicate.tap do |transaction|
          transaction.set_error(error)
          transaction.complete
        end
      end

      ext.complete
    end

    # @api private
    def pause!
      @paused = true
    end

    # @api private
    def resume!
      @paused = false
    end

    # @api private
    def paused?
      @paused == true
    end

    # @api private
    def discard!
      @discarded = true
    end

    # @api private
    def restore!
      @discarded = false
    end

    # @api private
    def discarded?
      @discarded == true
    end

    # @api private
    def store(key)
      @store[key]
    end

    # Set parameters on the transaction.
    #
    # When no parameters are set this way, the transaction will look for
    # parameters on the {#request} environment.
    #
    # The parameters set using {#set_params} are leading over those extracted
    # from a request's environment.
    #
    # When both the `given_params` and a block is given to this method, the
    # `given_params` argument is leading and the block will _not_ be called.
    #
    # @since 3.9.1
    # @param given_params [Hash] The parameters to set on the transaction.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @return [void]
    # @see Helpers::Instrumentation#set_params
    def set_params(given_params = nil, &block)
      @params = block if block
      @params = given_params if given_params
    end

    # Set parameters on the transaction if not already set
    #
    # When no parameters are set this way, the transaction will look for
    # parameters on the {#request} environment.
    #
    # @since 3.9.1
    # @param given_params [Hash] The parameters to set on the transaction if none are already set.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @return [void]
    #
    # @see #set_params
    # @see Helpers::Instrumentation#set_params_if_nil
    def set_params_if_nil(given_params = nil, &block)
      set_params(given_params, &block) unless @params
    end

    # Set tags on the transaction.
    #
    # When this method is called multiple times, it will merge the tags.
    #
    # @param given_tags [Hash] Collection of tags.
    # @option given_tags [String, Symbol, Integer] :any
    #   The name of the tag as a Symbol.
    # @option given_tags [String, Symbol, Integer] "any"
    #   The name of the tag as a String.
    # @return [void]
    #
    # @see Helpers::Instrumentation#tag_request
    # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    def set_tags(given_tags = {})
      @tags.merge!(given_tags)
    end

    # Set session data on the transaction.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the `given_session_data` argument is leading and the block will _not_ be
    # called.
    #
    # @param given_session_data [Hash] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @return [void]
    #
    # @since 3.10.1
    # @see Helpers::Instrumentation#set_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def set_session_data(given_session_data = nil, &block)
      @session_data = block if block
      @session_data = given_session_data if given_session_data
    end

    # Set session data on the transaction if not already set.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the `given_session_data` argument is leading and the block will _not_ be
    # called.
    #
    # @param given_session_data [Hash] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @return [void]
    #
    # @since 3.10.1
    # @see #set_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def set_session_data_if_nil(given_session_data = nil, &block)
      set_session_data(given_session_data, &block) unless @session_data
    end

    # Set headers on the transaction.
    #
    # When both the `given_headers` and a block is given to this method,
    # the `given_headers` argument is leading and the block will _not_ be
    # called.
    #
    # @param given_headers [Hash] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @return [void]
    #
    # @since 3.10.1
    # @see Helpers::Instrumentation#set_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def set_headers(given_headers = nil, &block)
      @headers = block if block
      @headers = given_headers if given_headers
    end

    # Set headers on the transaction if not already set.
    #
    # When both the `given_headers` and a block is given to this method,
    # the `given_headers` argument is leading and the block will _not_ be
    # called.
    #
    # @param given_headers [Hash] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @return [void]
    #
    # @since 3.10.1
    # @see #set_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def set_headers_if_nil(given_headers = nil, &block)
      set_headers(given_headers, &block) unless @headers
    end

    # Set custom data on the transaction.
    #
    # When this method is called multiple times, it will overwrite the
    # previously set value.
    #
    # @since 3.10.0
    # @see Appsignal.set_custom_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    # @param data [Hash/Array]
    # @return [void]
    def set_custom_data(data)
      case data
      when Array, Hash
        @custom_data = data
      else
        Appsignal.internal_logger
          .error("set_custom_data: Unsupported data type #{data.class} received.")
      end
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
      unless metadata.is_a? Hash
        Appsignal.internal_logger.error "add_breadcrumb: Cannot add breadcrumb. " \
          "The given metadata argument is not a Hash."
        return
      end

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

    # Set queue start time for transaction.
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
      Appsignal.internal_logger.warn("Queue start value #{start} is too big")
    end

    # @api private
    def set_metadata(key, value)
      return unless key && value
      return if Appsignal.config[:filter_metadata].include?(key.to_s)

      @ext.set_metadata(key, value)
    end

    def add_error(error)
      @errors << error
      return unless @errors.length > ADDITIONAL_ERRORS_LIMIT

      Appsignal.internal_logger.debug "Appsignal::Transaction#add_error: Transaction has more " \
        "than #{ADDITIONAL_ERRORS_LIMIT} additional errors. Only the last " \
        "#{ADDITIONAL_ERRORS_LIMIT} will be reported."
      @errors = @errors.last(ADDITIONAL_ERRORS_LIMIT)
    end

    # @see Appsignal::Helpers::Instrumentation#set_error
    def set_error(error)
      unless error.is_a?(Exception)
        Appsignal.internal_logger.error "Appsignal::Transaction#set_error: Cannot set error. " \
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

      @has_error = true

      root_cause_missing = false

      causes = []
      while error
        error = error.cause

        break unless error

        if causes.length >= ERROR_CAUSES_LIMIT
          Appsignal.internal_logger.debug "Appsignal::Transaction#set_error: Error has more " \
            "than #{ERROR_CAUSES_LIMIT} error causes. Only the first #{ERROR_CAUSES_LIMIT} " \
            "will be reported."
          root_cause_missing = true
          break
        end

        causes << error
      end

      causes_sample_data = causes.map do |e|
        {
          :name => e.class.name,
          :message => cleaned_error_message(e)
        }
      end

      causes_sample_data.last[:is_root_cause] = false if root_cause_missing

      set_sample_data(
        "error_causes",
        causes_sample_data
      )
    end
    alias_method :add_exception, :set_error

    # @see Helpers::Instrumentation#instrument
    # @api private
    def start_event
      return if paused?

      @ext.start_event(0)
    end

    # @see Helpers::Instrumentation#instrument
    # @api private
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

    # @see Helpers::Instrumentation#instrument
    # @api private
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

    # @see Helpers::Instrumentation#instrument
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

    protected

    attr_writer :ext, :is_duplicate

    private

    def set_sample_data(key, data)
      return unless key && data

      if !data.is_a?(Array) && !data.is_a?(Hash)
        Appsignal.internal_logger.error(
          "Invalid sample data for '#{key}'. Value is not an Array or Hash: '#{data.inspect}'"
        )
        return
      end

      @ext.set_sample_data(
        key.to_s,
        Appsignal::Utils::Data.generate(data)
      )
    rescue RuntimeError => e
      begin
        inspected_data = data.inspect
        Appsignal.internal_logger.error(
          "Error generating data (#{e.class}: #{e.message}) for '#{inspected_data}'"
        )
      rescue => e
        Appsignal.internal_logger.error(
          "Error generating data (#{e.class}: #{e.message}). Can't inspect data."
        )
      end
    end

    def sample_data
      {
        :params => sanitized_params,
        :environment => sanitized_request_headers,
        :session_data => sanitized_session_data,
        :tags => sanitized_tags,
        :breadcrumbs => breadcrumbs,
        :custom_data => custom_data
      }.each do |key, data|
        set_sample_data(key, data)
      end
    end

    def duplicate
      new_transaction_id = SecureRandom.uuid

      self.class.new(
        new_transaction_id,
        namespace,
        :ext => ext.duplicate(new_transaction_id)
      ).tap do |transaction|
        transaction.is_duplicate = true
      end
    end

    # @api private
    def params
      return unless @params

      if @params.respond_to? :call
        @params.call
      else
        @params
      end
    rescue => e
      Appsignal.internal_logger.error("Exception while fetching params: #{e.class}: #{e}")
      nil
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
        Appsignal.internal_logger.warn "Exception while getting params: #{e}"
        nil
      end
    end

    def session_data
      return unless @session_data

      if @session_data.respond_to? :call
        @session_data.call
      else
        @session_data
      end
    rescue => e
      Appsignal.internal_logger.error \
        "Exception while fetching session data: #{e.class}: #{e}"
      nil
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
      return unless Appsignal.config[:send_session_data]

      Appsignal::Utils::HashSanitizer.sanitize(
        session_data&.to_hash, Appsignal.config[:filter_session_data]
      )
    end

    def request_headers
      if @headers.respond_to? :call
        @headers.call
      else
        @headers
      end
    rescue => e
      Appsignal.internal_logger.error \
        "Exception while fetching headers: #{e.class}: #{e}"
      nil
    end

    # Returns sanitized environment for a transaction.
    #
    # The environment of a transaction can contain a lot of information, not
    # all of it useful for debugging.
    #
    # @return [nil] if no environment is present.
    # @return [Hash<String, Object>]
    def sanitized_request_headers
      headers = request_headers
      return unless headers

      {}.tap do |out|
        Appsignal.config[:request_headers].each do |key|
          out[key] = headers[key] if headers[key]
        end
      end
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
