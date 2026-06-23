# frozen_string_literal: true

require "json"

module Appsignal
  class Transaction
    # @return [String]
    HTTP_REQUEST   = "http_request"
    # @return [String]
    BACKGROUND_JOB = "background_job"
    # @!visibility private
    ACTION_CABLE   = "action_cable"
    # @!visibility private
    BLANK          = ""
    # @!visibility private
    ALLOWED_TAG_KEY_TYPES = [Symbol, String].freeze
    # @!visibility private
    ALLOWED_TAG_VALUE_TYPES = [Symbol, String, Integer, TrueClass, FalseClass].freeze
    # @!visibility private
    BREADCRUMB_LIMIT = 20
    # @!visibility private
    ERROR_CAUSES_LIMIT = 10
    # @!visibility private
    ERRORS_LIMIT = 10

    class << self
      # Create a new transaction and set it as the currently active
      # transaction.
      #
      # @param namespace [String] Namespace of the to be created transaction.
      # @return [Transaction]
      def create(namespace)
        # Reset the transaction if it was already completed but not cleared
        if Thread.current[:appsignal_transaction]&.completed?
          Thread.current[:appsignal_transaction] = nil
        end

        if Thread.current[:appsignal_transaction].nil?
          # If not, start a new transaction
          set_current_transaction(Appsignal::Transaction.new(namespace))
        else
          transaction = current
          # Otherwise, log the issue about trying to start another transaction
          Appsignal.internal_logger.warn(
            "Trying to start new transaction, but a transaction " \
              "with id '#{transaction.transaction_id}' is already running. " \
              "Using transaction '#{transaction.transaction_id}'."
          )

          # And return the current transaction instead
          transaction
        end
      end

      # Add a block, if given, to be executed after a transaction is created.
      # The block will be called with the transaction as an argument.
      # Returns the array of blocks that will be executed after a transaction
      # is created.
      #
      # @return [Array<Proc>]
      # @!visibility private
      def after_create(&block)
        @after_create ||= Set.new

        return @after_create if block.nil?

        @after_create << block
      end

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
      #
      # @return [Array<Proc>]
      # @!visibility private
      def before_complete(&block)
        @before_complete ||= Set.new

        return @before_complete if block.nil?

        @before_complete << block
      end

      # @!visibility private
      def set_current_transaction(transaction)
        Thread.current[:appsignal_transaction] = transaction
      end

      # Set the current for the duration of the given block.
      # It restores the original transaction (if any) when the block has executed.
      #
      # @!visibility private
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
      # @return [Appsignal::Transaction, Appsignal::Transaction::NilTransaction]
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
      #
      # @return [void]
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
      # @!visibility private
      def clear_current_transaction!
        Thread.current[:appsignal_transaction] = nil
      end

      # @!visibility private
      def last_errors
        @last_errors ||= []
      end

      # @!visibility private
      attr_writer :last_errors
    end

    # @!visibility private
    attr_reader :transaction_id, :action, :namespace

    # Use {.create} to create new transactions.
    #
    # @param namespace [String] Namespace of the to be created transaction.
    # @see create
    # @!visibility private
    def initialize(namespace, id: SecureRandom.uuid, backend: nil)
      @transaction_id = id
      @action = nil
      @namespace = namespace
      @paused = false
      @discarded = false
      @completed = false
      @tags = {}
      @store = Hash.new { |hash, key| hash[key] = {} }
      @error_blocks = Hash.new { |hash, key| hash[key] = [] }
      @is_duplicate = false
      @error_set = nil

      @params = Appsignal::SampleData.new(:params)
      @session_data = Appsignal::SampleData.new(:session_data, Hash)
      @headers = Appsignal::SampleData.new(:headers, Hash)
      @custom_data = Appsignal::SampleData.new(:custom_data)

      @backend = backend || Appsignal::Backends.transaction.new(
        @transaction_id,
        @namespace
      )

      run_after_create_hooks
    end

    # @!visibility private
    def duplicate?
      @is_duplicate
    end

    # @!visibility private
    def nil_transaction?
      false
    end

    # @!visibility private
    def completed?
      @completed
    end

    # @!visibility private
    def complete
      # Completing is idempotent: a transaction can be completed explicitly and
      # then again by a `complete_current!` cleanup path. Re-running would, for a
      # multi-error transaction, re-record the extra errors (a second duplicate
      # in agent mode, or an event on an already-finished span in collector mode).
      return if completed?

      if discarded?
        Appsignal.internal_logger.debug "Skipping transaction '#{transaction_id}' " \
          "because it was manually discarded."
        # Let the backend tear itself down. The agent backend drops the
        # transaction (nothing is sent); the OpenTelemetry backend still
        # finishes and exports the root span, but flags it with
        # `appsignal.ignore_subtrace` so the collector ignores the subtrace.
        # `@completed` stays false either way: a discarded transaction was
        # never reported.
        @backend.discard
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
        should_sample = @backend.finish
      end

      report_errors

      run_before_complete_hooks

      sample_data if should_sample

      @completed = true
      @backend.complete
    end

    # @!visibility private
    def pause!
      @paused = true
    end

    # @!visibility private
    def resume!
      @paused = false
    end

    # @!visibility private
    def paused?
      @paused == true
    end

    # @!visibility private
    def discard!
      @discarded = true
    end

    # @!visibility private
    def restore!
      @discarded = false
    end

    # @!visibility private
    def discarded?
      @discarded == true
    end

    # @!visibility private
    def store(key)
      @store[key]
    end

    # @!visibility private
    #
    # Run a block during which downstream HTTP client integrations (Net::HTTP,
    # ...) skip recording their own event. Used when an outer HTTP client
    # integration (Faraday) already records the request, so the same request is
    # not instrumented twice as nested client events.
    def suppress_http_client_events
      # Restore the previous value rather than forcing `false`, so nested calls
      # don't unsuppress while an outer block is still active.
      previously_suppressed = store("http_client")[:suppressed]
      store("http_client")[:suppressed] = true
      yield
    ensure
      store("http_client")[:suppressed] = previously_suppressed
    end

    # @!visibility private
    def http_client_events_suppressed?
      store("http_client")[:suppressed] == true
    end

    # @!visibility private
    #
    # Run a block during which nested job enqueue integrations (Sidekiq, Resque,
    # ...) skip recording their own enqueue event. Used when an outer integration
    # (Active Job) already records the enqueue, so the same enqueue is not
    # instrumented twice as nested enqueue events.
    def suppress_job_enqueue_events
      # Restore the previous value rather than forcing `false`, so nested calls
      # don't unsuppress while an outer block is still active.
      previously_suppressed = store("job_enqueue")[:suppressed]
      store("job_enqueue")[:suppressed] = true
      yield
    ensure
      store("job_enqueue")[:suppressed] = previously_suppressed
    end

    # @!visibility private
    def job_enqueue_events_suppressed?
      store("job_enqueue")[:suppressed] == true
    end

    # Add parameters to the transaction.
    #
    # When this method is called multiple times, it will merge the request parameters.
    #
    # When both the `given_params` and a block is given to this method, the
    # block is leading and the argument will _not_ be used.
    #
    # @since 4.0.0
    # @param given_params [Hash<String, Object>, Array<Object>] The parameters to set on the
    #   transaction.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @yieldreturn [Hash<String, Object>, Array<Object>]
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_params
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_params(given_params = nil, &block)
      @params.add(given_params, &block)
    end
    alias set_params add_params

    # @since 4.0.0
    # @return [void]
    # @!visibility private
    #
    # @see Helpers::Instrumentation#set_empty_params!
    def set_empty_params!
      @params.set_empty_value!
    end

    # Add parameters to the transaction if not already set.
    #
    # @since 4.0.0
    # @param given_params [Hash<String, Object>, Array<Object>] The parameters to set on the
    #   transaction if none are already set.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new parameters.
    # @yieldreturn [Hash<String, Object>, Array<Object>]
    # @return [void]
    # @!visibility private
    #
    # @see #add_params
    def add_params_if_nil(given_params = nil, &block)
      add_params(given_params, &block) if !@params.value? && !@params.empty?
    end
    alias set_params_if_nil add_params_if_nil

    # Add tags to the transaction.
    #
    # When this method is called multiple times, it will merge the tags.
    #
    # @since 4.0.0
    # @param given_tags [Hash<String, Object>] Collection of tags.
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
    alias set_tags add_tags

    # Add session data to the transaction.
    #
    # When this method is called multiple times, it will merge the session data.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the block is leading and the argument will _not_ be used.
    #
    # @since 4.0.0
    # @param given_session_data [Hash<String, Object>] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @yieldreturn [Hash<String, Object>]
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_session_data(given_session_data = nil, &block)
      @session_data.add(given_session_data, &block)
    end
    alias set_session_data add_session_data

    # Set session data on the transaction if not already set.
    #
    # When both the `given_session_data` and a block is given to this method,
    # the `given_session_data` argument is leading and the block will _not_ be
    # called.
    #
    # @since 4.0.0
    # @param given_session_data [Hash<String, Object>] A hash containing session data.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new session data.
    # @yieldreturn [Hash<String, Object>]
    # @return [void]
    # @!visibility private
    #
    # @see #add_session_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_session_data_if_nil(given_session_data = nil, &block)
      add_session_data(given_session_data, &block) unless @session_data.value?
    end
    alias set_session_data_if_nil add_session_data_if_nil

    # Add headers to the transaction.
    #
    # @since 4.0.0
    # @param given_headers [Hash<String, Object>] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @yieldreturn [Hash<String, Object>]
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_headers(given_headers = nil, &block)
      @headers.add(given_headers, &block)
    end
    alias set_headers add_headers

    # Add headers to the transaction if not already set.
    #
    # When both the `given_headers` and a block is given to this method,
    # the block is leading and the argument will _not_ be used.
    #
    # @since 4.0.0
    # @param given_headers [Hash<String, Object>] A hash containing headers.
    # @yield This block is called when the transaction is sampled. The block's
    #   return value will become the new headers.
    # @yieldreturn [Hash<String, Object>]
    # @return [void]
    # @!visibility private
    #
    # @see #add_headers
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_headers_if_nil(given_headers = nil, &block)
      add_headers(given_headers, &block) unless @headers.value?
    end
    alias set_headers_if_nil add_headers_if_nil

    # Add custom data to the transaction.
    #
    # @since 4.0.0
    # @param data [Hash<Object, Object>, Array<Object>] Custom data to add to
    #   the transaction.
    # @return [void]
    #
    # @see Helpers::Instrumentation#add_custom_data
    # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
    #   Sample data guide
    def add_custom_data(data)
      @custom_data.add(data)
    end
    alias set_custom_data add_custom_data

    # Add breadcrumbs to the transaction.
    #
    # @param category [String] category of breadcrumb
    #   e.g. "UI", "Network", "Navigation", "Console".
    # @param action [String] name of breadcrumb
    #   e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
    # @param message [String]  optional message in string format
    # @param metadata [Hash<String,String>]  key/value metadata in <string, string> format
    # @param time [Time] time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
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

      # The backend owns how breadcrumbs are stored: the agent backend buffers
      # them and flushes at completion, the OpenTelemetry backend emits each as a
      # span event right away (by completion its target span has finished).
      @backend.add_breadcrumb(
        :time => time.to_i,
        :category => category,
        :action => action,
        :message => message,
        :metadata => metadata
      )
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
      @backend.set_action(action)
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
    # @since 2.2.0
    # @param action [String]
    # @return [void]
    # @!visibility private
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
      @backend.set_namespace(namespace)
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

      @backend.set_queue_start(start)
    rescue RangeError
      Appsignal.internal_logger.warn("Queue start value #{start} is too big")
    end

    # @!visibility private
    def set_metadata(key, value)
      return unless key && value
      return if Appsignal.config[:filter_metadata].include?(key.to_s)

      @backend.set_metadata(key, value)
    end

    # @!visibility private
    # @see Appsignal::Helpers::Instrumentation#report_error
    def add_error(error, &block)
      unless error.is_a?(Exception)
        Appsignal.internal_logger.error "Appsignal::Transaction#add_error: Cannot add error. " \
          "The given value is not an exception: #{error.inspect}"
        return
      end

      return unless error
      return unless Appsignal.active?

      if error.instance_variable_get(:@__appsignal_error_reported) && !@error_blocks.include?(error)
        return
      end

      internal_set_error(error, &block)

      # Mark errors and their causes as tracked so we don't report duplicates,
      # but also not error causes if the wrapper error is already reported.
      while error
        error.instance_variable_set(:@__appsignal_error_reported, true) unless error.frozen?
        error = error.cause
      end
    end
    alias set_error add_error
    alias add_exception add_error

    # @!visibility private
    # @see Helpers::Instrumentation#instrument
    def start_event(opentelemetry_kind: nil)
      return if paused?

      @backend.start_event(:opentelemetry_kind => opentelemetry_kind)
    end

    # @!visibility private
    # @see Helpers::Instrumentation#instrument
    def finish_event(name, title, body, body_format = Appsignal::EventFormatter::DEFAULT)
      return if paused?

      @backend.finish_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT
      )
    end

    # @!visibility private
    # @see Helpers::Instrumentation#instrument
    def record_event(name, title, body, duration, body_format = Appsignal::EventFormatter::DEFAULT)
      return if paused?

      @backend.record_event(
        name,
        title || BLANK,
        body || BLANK,
        body_format || Appsignal::EventFormatter::DEFAULT,
        duration
      )
    end

    # @!visibility private
    # @see Helpers::Instrumentation#instrument
    def instrument(
      name,
      title = nil,
      body = nil,
      body_format = Appsignal::EventFormatter::DEFAULT,
      opentelemetry_kind: nil
    )
      start_event(:opentelemetry_kind => opentelemetry_kind)
      yield if block_given?
    ensure
      finish_event(name, title, body, body_format)
    end

    # @!visibility private
    def to_h
      JSON.parse(@backend.to_json)
    end
    alias to_hash to_h

    protected

    # @!visibility private
    attr_writer :is_duplicate, :tags, :custom_data, :params,
      :session_data, :headers

    # @!visibility private
    def internal_set_error(error, &block)
      is_new_error = !@error_blocks.include?(error)

      if is_new_error && @error_blocks.length >= ERRORS_LIMIT
        Appsignal.internal_logger.warn "Appsignal::Transaction#add_error: Transaction has more " \
          "than #{ERRORS_LIMIT} distinct errors. Only the first " \
          "#{ERRORS_LIMIT} distinct errors will be reported."
        return
      end

      if @error_blocks.empty?
        _set_error(error)
      elsif is_new_error && @backend.records_errors_eagerly?
        # Record additional errors immediately so each exception event lands on
        # the span current now, not the root span at completion. The agent
        # backend instead reports extras as duplicate transactions.
        _send_error_to_backend(error)
      end

      @error_blocks[error] << block
      @error_blocks[error].compact!
    end

    private

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

    # Reports the errors stored on the transaction at completion, in one of two
    # ways depending on the backend:
    #
    #   - eager (collector): each error was already recorded as its own exception
    #     event when added, on the span current at that moment; here we only run
    #     the error blocks.
    #   - deferred (agent): the extension holds a single error, so the primary
    #     error's blocks run on this transaction and every additional error is
    #     reported as a duplicate transaction.
    def report_errors
      if @backend.records_errors_eagerly?
        run_error_blocks
      else
        report_errors_as_duplicates
      end
    end

    # Eager mode: the errors are already recorded, so just run their blocks.
    # Blocks run in add-order, so a later error's block wins on a shared key, and
    # all block-set metadata merges onto the root span. (Per-error metadata
    # isolation is deferred -- the processor/UI does not read per-event
    # attributes yet.)
    def run_error_blocks
      @error_blocks.each_value do |blocks|
        self.class.with_transaction(self) do
          blocks.each { |block| block.call(self) }
        end
      end
    end

    # Agent mode: the extension transaction holds a single error, so report each
    # additional error as a duplicate transaction.
    def report_errors_as_duplicates
      @error_blocks.each do |error, blocks|
        # Ignore the error that is already set in this transaction.
        next if error == @error_set

        duplicate.tap do |transaction|
          # In the duplicate transaction for each error, set an error
          # with a block that calls all the blocks set for that error
          # in the original transaction.
          transaction.internal_set_error(error) do
            blocks.each { |block| block.call(transaction) }
          end

          transaction.complete
        end
      end

      return unless @error_set && @error_blocks[@error_set].any?

      self.class.with_transaction(self) do
        @error_blocks[@error_set].each do |block|
          block.call(self)
        end
      end
    end

    def _set_error(error)
      @error_set = error
      _send_error_to_backend(error)
    end

    # Records an error on the backend. The cause chain is walked once into
    # neutral data ({name, message, backtrace}); each backend projects what it
    # needs -- the agent's first-line `error_causes` sample data, or the
    # OpenTelemetry `appsignal.error_causes` attribute. Called for the first
    # error and, in collector mode, for each additional error as it is added.
    def _send_error_to_backend(error)
      causes, root_cause_missing = _error_causes(error)
      @backend.set_error(
        error.class.name,
        cleaned_error_message(error),
        cleaned_backtrace(error.backtrace),
        causes.map do |cause|
          {
            :name => cause.class.name,
            :message => cleaned_error_message(cause),
            :backtrace => cleaned_backtrace(cause.backtrace)
          }
        end,
        root_cause_missing
      )
    end

    # Walks the `error.cause` chain (without mutating `error`), collecting up to
    # `ERROR_CAUSES_LIMIT` causes. Returns the causes and whether the chain was
    # truncated (the root cause is missing).
    def _error_causes(error)
      root_cause_missing = false
      causes = []
      cause = error
      while (cause = cause.cause)
        if causes.length >= ERROR_CAUSES_LIMIT
          Appsignal.internal_logger.debug "Appsignal::Transaction#add_error: Error has more " \
            "than #{ERROR_CAUSES_LIMIT} error causes. Only the first #{ERROR_CAUSES_LIMIT} " \
            "will be reported."
          root_cause_missing = true
          break
        end

        causes << cause
      end

      [causes, root_cause_missing]
    end

    def set_sample_data(key, data)
      return unless key && data

      if !data.is_a?(Array) && !data.is_a?(Hash)
        Appsignal.internal_logger.error(
          "Invalid sample data for '#{key}'. Value is not an Array or Hash: '#{data.inspect}'"
        )
        return
      end

      # Pass raw Ruby through to the backend. ExtensionBackend serializes to a
      # C-extension `Data` object; OpenTelemetryBackend reads the Hash/Array
      # directly. The `RuntimeError` rescue still covers ExtensionBackend's
      # `Data.generate`, which now runs inside the backend call.
      @backend.set_sample_data(key.to_s, data)
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
        :backend => @backend.duplicate(new_transaction_id)
      ).tap do |transaction|
        transaction.is_duplicate = true
        transaction.tags = @tags.dup
        transaction.custom_data = @custom_data.dup
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
      # Start with config default_tags as base (if config is available)
      base_tags = if Appsignal.config
                    Appsignal.config[:default_tags] || {}
                  else
                    {}
                  end

      # Merge transaction tags on top (transaction tags take priority)
      all_tags = base_tags.merge(@tags)

      # Apply existing sanitization filter
      all_tags.select do |key, value|
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
    #
    # @!visibility private
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
