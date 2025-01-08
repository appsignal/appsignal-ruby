# frozen_string_literal: true

require "json"

module Appsignal
  class Transaction
    HTTP_REQUEST   = "http_request"
    BACKGROUND_JOB = "background_job"
    # @api private
    ACTION_CABLE   = "action_cable"
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
    ERRORS_LIMIT = 10

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
          set_current_transaction(Appsignal::Transaction.new(namespace))
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

      # @api private
      # @return [Array<Proc>]
      # Add a block, if given, to be executed after a transaction is created.
      # The block will be called with the transaction as an argument.
      # Returns the array of blocks that will be executed after a transaction
      # is created.
      def after_create(&block)
        @after_create ||= Set.new

        return @after_create if block.nil?

        @after_create << block
      end

      # @api private
      # @return [Array<Proc>]
      # Add a block, if given, to be executed before a transaction is completed.
      # This happens after duplicating the transaction for each error that was
      # reported in the transaction -- that is, when a transaction with
      # several errors is completed, the block will be called once for each
      # error, with the transaction (either the original one or a duplicate of it)
      # that has each of the errors set.
      # The block will be called with the transaction as the first argument,
      # and the error reported by the transaction, if any, as the second argument.
      # Returns the array of blocks that will be executed before a transaction is
      # completed.
      def before_complete(&block)
        @before_complete ||= Set.new

        return @before_complete if block.nil?

        @before_complete << block
      end

      # @api private
      def set_current_transaction(transaction)
        Thread.current[:appsignal_transaction] = transaction
      end

      # Set the current for the duration of the given block.
      # It restores the original transaction (if any) when the block has executed.
      #
      # @api private
      def with_transaction(transaction)
        original_transaction = current if current?
        set_current_transaction(transaction)
        yield
      ensure
        set_current_transaction(original_transaction)
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

      # @api private
      def last_errors
        @last_errors ||= []
      end

      # @api private
      attr_writer :last_errors
    end

    # @api private
    attr_reader :transaction_id, :action, :namespace

    # Use {.create} to create new transactions.
    #
    # @param namespace [String] Namespace of the to be created transaction.
    # @see create
    # @api private
    def initialize(namespace, id: SecureRandom.uuid, ext: nil)
      @transaction_id = id
      @action = nil
      @namespace = namespace
      @paused = false
      @discarded = false
      @tags = {}
      @breadcrumbs = []
      @store = Hash.new { |hash, key| hash[key] = {} }
      @error_blocks = Hash.new { |hash, key| hash[key] = [] }
      @is_duplicate = false
      @error_set = nil

      @params = Appsignal::SampleData.new(:params)
      @session_data = Appsignal::SampleData.new(:session_data, Hash)
      @headers = Appsignal::SampleData.new(:headers, Hash)
      @custom_data = Appsignal::SampleData.new(:custom_data)

      @ext = ext || Appsignal::Extension.start_transaction(
        @transaction_id,
        @namespace,
        0
      ) || Appsignal::Extension::MockTransaction.new

      run_after_create_hooks
    end

    # @api private
    def duplicate?
      @is_duplicate
    end

    # @api private
    def nil_transaction?
      false
    end

    # @api private
    def complete
      if discarded?
        Appsignal.internal_logger.debug "Skipping transaction '#{transaction_id}' " \
          "because it was manually discarded."
        return
      end

      # If the transaction is a duplicate, we don't want to finish it,
      # because we want its finish time to be the finish time of the
      # original transaction.
      # Duplicate transactions should always be sampled, as we only
      # create duplicates for errors, which are always sampled.
      should_sample = true

      unless duplicate?
        self.class.last_errors = @error_blocks.keys
        should_sample = @ext.finish(0)
      end

      @error_blocks.each do |error, blocks|
        # Ignore the error that is already set in this transaction.
        next if error == @error_set

        duplicate.tap do |transaction|
          # In the duplicate transaction for each error, set an error
          # with a block that calls all the blocks set for that error
          # in the original transaction.
          transaction.set_error(error) do
            blocks.each { |block| block.call(transaction) }
          end

          transaction.complete
        end
      end

      if @error_set && @error_blocks[@error_set].any?
        self.class.with_transaction(self) do
          @error_blocks[@error_set].each do |block|
            block.call(self)
          end
        end
      end

      run_before_complete_hooks

      sample_data if should_sample

      @ext.complete
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

    # Add parameters to the transaction.
    #
    # When this method is called multiple times, it will merge the request parameters.
    #
    # When both the `given_params` and a block is given to this method, the
    # block is leading and the argument will _not_ be used.
    #
    # @since 4.0.0
    # @param given_params [Hash] The parameters to set on the transaction.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_params
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_params(given_params = nil, &block)
      @params.add(given_params, &block)
    end
    alias :set_params :add_params

    # @api private
    # @since 4.0.0
    # @return [void]
    #
    # @see Helpers::Instrumentation#set_empty_params!
    def set_empty_params!
      @params.set_empty_value!
    end

    # Add parameters to the transaction if not already set.
    #
    # @api private
    # @since 4.0.0
    # @param given_params [Hash] The parameters to set on the transaction if none are already set.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @return [void]
    #
    # @see #add_params
    def add_params_if_nil(given_params = nil, &block)
      add_params(given_params, &block) if !@params.value? && !@params.empty?
    end
    alias :set_params_if_nil :add_params_if_nil

    # Add tags to the transaction.
    #
    # When this method is called multiple times, it will merge the tags.
    #
    # @since 4.0.0
    # @param given_tags [Hash] Collection of tags.
    # @option given_tags [String, Symbol, Integer] :any
    #   The name of the tag as a Symbol.
    # @option given_tags [String, Symbol, Integer] "any"
    #   The name of the tag as a String.
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_tags
    # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    def add_tags(given_tags = {})
      @tags.merge!(given_tags)
    end
    alias :set_tags :add_tags

    # Add session data to the transaction.
    #
    # When this method is called multiple times, it will merge the session data.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the block is leading and the argument will _not_ be used.
    #
    # @since 4.0.0
    # @param given_session_data [Hash] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_session_data(given_session_data = nil, &block)
      @session_data.add(given_session_data, &block)
    end
    alias :set_session_data :add_session_data

    # Set session data on the transaction if not already set.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the `given_session_data` argument is leading and the block will _not_ be
    # called.
    #
    # @api private
    # @since 4.0.0
    # @param given_session_data [Hash] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @return [void]
    #
    # @see #add_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_session_data_if_nil(given_session_data = nil, &block)
      add_session_data(given_session_data, &block) unless @session_data.value?
    end
    alias :set_session_data_if_nil :add_session_data_if_nil

    # Add headers to the transaction.
    #
    # @since 4.0.0
    # @param given_headers [Hash] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_headers(given_headers = nil, &block)
      @headers.add(given_headers, &block)
    end
    alias :set_headers :add_headers

    # Add headers to the transaction if not already set.
    #
    # When both the `given_headers` and a block is given to this method,
    # the block is leading and the argument will _not_ be used.
    #
    # @api private
    # @since 4.0.0
    # @param given_headers [Hash] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @return [void]
    #
    # @see #add_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_headers_if_nil(given_headers = nil, &block)
      add_headers(given_headers, &block) unless @headers.value?
    end
    alias :set_headers_if_nil :add_headers_if_nil

    # Add custom data to the transaction.
    #
    # @since 4.0.0
    # @param data [Hash/Array]
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_custom_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_custom_data(data)
      @custom_data.add(data)
    end
    alias :set_custom_data :add_custom_data

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
    # @since 2.2.0
    # @param action [String] the action name to set.
    # @return [void]
    #
    # @see Appsignal::Helpers::Instrumentation#set_action
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
    # @api private
    # @since 2.2.0
    # @param action [String]
    # @return [void]
    #
    # @see #set_action
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
    # @since 2.2.0
    # @param namespace [String] namespace name to use for this transaction.
    # @return [void]
    #
    # @see Appsignal::Helpers::Instrumentation#set_namespace
    # @see https://docs.appsignal.com/guides/namespaces.html
    #   Grouping with namespaces guide
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

    # @api private
    # @see Appsignal::Helpers::Instrumentation#report_error
    def add_error(error, &block)
      unless error.is_a?(Exception)
        Appsignal.internal_logger.error "Appsignal::Transaction#add_error: Cannot add error. " \
          "The given value is not an exception: #{error.inspect}"
        return
      end

      return unless error
      return unless Appsignal.active?

      _set_error(error) if @error_blocks.empty?

      if !@error_blocks.include?(error) && @error_blocks.length >= ERRORS_LIMIT
        Appsignal.internal_logger.warn "Appsignal::Transaction#add_error: Transaction has more " \
          "than #{ERRORS_LIMIT} distinct errors. Only the first " \
          "#{ERRORS_LIMIT} distinct errors will be reported."
        return
      end

      @error_blocks[error] << block
      @error_blocks[error].compact!
    end
    alias :set_error :add_error
    alias_method :add_exception, :add_error

    # @api private
    # @see Helpers::Instrumentation#instrument
    def start_event
      return if paused?

      @ext.start_event(0)
    end

    # @api private
    # @see Helpers::Instrumentation#instrument
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

    # @api private
    # @see Helpers::Instrumentation#instrument
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

    # @api private
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

    attr_writer :is_duplicate, :tags, :custom_data, :breadcrumbs, :params,
      :session_data, :headers

    private

    attr_reader :breadcrumbs

    def run_after_create_hooks
      self.class.after_create.each do |block|
        block.call(self)
      end
    end

    def run_before_complete_hooks
      self.class.before_complete.each do |block|
        block.call(self, @error_set)
      end
    end

    def _set_error(error)
      backtrace = cleaned_backtrace(error.backtrace)
      @ext.set_error(
        error.class.name,
        cleaned_error_message(error),
        backtrace ? Appsignal::Utils::Data.generate(backtrace) : Appsignal::Extension.data_array_new
      )
      @error_set = error

      root_cause_missing = false

      causes = []
      while error
        error = error.cause

        break unless error

        if causes.length >= ERROR_CAUSES_LIMIT
          Appsignal.internal_logger.debug "Appsignal::Transaction#add_error: Error has more " \
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
          :message => cleaned_error_message(e),
          :first_line => first_formatted_backtrace_line(e)
        }
      end

      causes_sample_data.last[:is_root_cause] = false if root_cause_missing

      set_sample_data(
        "error_causes",
        causes_sample_data
      )
    end

    BACKTRACE_REGEX =
      %r{(?<gem>[\w-]+ \(.+\) )?(?<path>:?/?\w+?.+?):(?<line>:?\d+)(?::in `(?<method>.+)')?$}.freeze

    def first_formatted_backtrace_line(error)
      backtrace = cleaned_backtrace(error.backtrace)
      first_line = backtrace&.first
      return unless first_line

      captures = BACKTRACE_REGEX.match(first_line)
      return unless captures

      captures.named_captures
        .merge("original" => first_line)
        .tap do |c|
          config = Appsignal.config
          # Strip of whitespace at the end of the gem name
          c["gem"] = c["gem"]&.strip
          # Strip the app path from the path if present
          root_path = config.root_path
          if c["path"].start_with?(root_path)
            c["path"].delete_prefix!(root_path)
            # Relative paths shouldn't start with a slash
            c["path"].delete_prefix!("/")
          end
          # Add revision for linking to the repository from the UI
          c["revision"] = config[:revision]
          # Convert line number to an integer
          c["line"] = c["line"].to_i
        end
    end

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
        namespace,
        :id => new_transaction_id,
        :ext => @ext.duplicate(new_transaction_id)
      ).tap do |transaction|
        transaction.is_duplicate = true
        transaction.tags = @tags.dup
        transaction.custom_data = @custom_data.dup
        transaction.breadcrumbs = @breadcrumbs.dup
        transaction.params = @params.dup
        transaction.session_data = @session_data.dup
        transaction.headers = @headers.dup
      end
    end

    def params
      @params.value
    rescue => e
      Appsignal.internal_logger.error("Exception while fetching params: #{e.class}: #{e}")
      nil
    end

    def sanitized_params
      return unless Appsignal.config[:send_params]

      filter_keys = Appsignal.config[:filter_parameters] || []
      Appsignal::Utils::SampleDataSanitizer.sanitize(params, filter_keys)
    end

    def session_data
      @session_data.value
    rescue => e
      Appsignal.internal_logger.error \
        "Exception while fetching session data: #{e.class}: #{e}"
      nil
    end

    # Returns sanitized session data.
    #
    # The session data is sanitized by the
    # {Appsignal::Utils::SampleDataSanitizer}.
    #
    # @return [nil] if `:send_session_data` config is set to `false`.
    # @return [nil] if the {#request} object doesn't respond to `#session`.
    # @return [nil] if the {#request} session data is `nil`.
    # @return [Hash<String, Object>]
    def sanitized_session_data
      return unless Appsignal.config[:send_session_data]

      Appsignal::Utils::SampleDataSanitizer.sanitize(
        session_data,
        Appsignal.config[:filter_session_data]
      )
    end

    def request_headers
      @headers.value
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

    def custom_data
      @custom_data.value
    rescue => e
      Appsignal.internal_logger.error("Exception while fetching custom data: #{e.class}: #{e}")
      nil
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
