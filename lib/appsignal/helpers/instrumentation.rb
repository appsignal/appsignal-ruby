# frozen_string_literal: true

module Appsignal
  module Helpers
    module Instrumentation
      # Monitor a block of code with AppSignal.
      #
      # This is a helper to create an AppSignal transaction, track any errors
      # that may occur and complete the transaction.
      #
      # This helper is recommended to be used in Ruby scripts and parts of an
      # app not already instrumented by AppSignal's automatic instrumentations.
      #
      # Use this helper in combination with our {.instrument} helper to track
      # instrumentation events.
      #
      # If AppSignal is not active ({Appsignal.active?}) it will still execute
      # the block, but not create a transaction for it.
      #
      # @example Instrument a block of code
      #   Appsignal.monitor(
      #     :namespace => "my_namespace",
      #     :action => "MyClass#my_method"
      #   ) do
      #     # Some code
      #   end
      #
      # @example Instrument a block of code using the default namespace
      #   Appsignal.monitor(
      #     :action => "MyClass#my_method"
      #   ) do
      #     # Some code
      #   end
      #
      # @example Instrument a block of code with an instrumentation event
      #   Appsignal.monitor(
      #     :namespace => "my_namespace",
      #     :action => "MyClass#my_method"
      #   ) do
      #     Appsignal.instrument("some_event.some_group") do
      #       # Some code
      #     end
      #   end
      #
      # @example Set the action name in the monitor block
      #   Appsignal.monitor(
      #     :action => nil
      #   ) do
      #     # Some code
      #
      #     Appsignal.set_action("GET /resource/:id")
      #   end
      #
      # @example Set the action name in the monitor block
      #   Appsignal.monitor(
      #     :action => :set_later # Explicit placeholder
      #   ) do
      #     # Some code
      #
      #     Appsignal.set_action("GET /resource/:id")
      #   end
      #
      # @example Set custom metadata on the transaction
      #   Appsignal.monitor(
      #     :namespace => "my_namespace",
      #     :action => "MyClass#my_method"
      #   ) do
      #     # Some code
      #
      #     Appsignal.add_tags(:tag1 => "value1", :tag2 => "value2")
      #     Appsignal.add_params(:param1 => "value1", :param2 => "value2")
      #   end
      #
      # @example Call monitor within monitor will do nothing
      #   Appsignal.monitor(
      #     :namespace => "my_namespace",
      #     :action => "MyClass#my_method"
      #   ) do
      #     # This will _not_ update the namespace and action name
      #     Appsignal.monitor(
      #       :namespace => "my_other_namespace",
      #       :action => "MyOtherClass#my_other_method"
      #     ) do
      #       # Some code
      #
      #       # The reported namespace will be "my_namespace"
      #       # The reported action will be "MyClass#my_method"
      #     end
      #   end
      #
      # @since 3.11.0
      # @param namespace [String/Symbol] The namespace to set on the new
      #   transaction.
      #   Defaults to the 'web' namespace.
      #   This will not update the active transaction's namespace if
      #   {.monitor} is called when another transaction is already active.
      # @param action [String, Symbol, NilClass]
      #   The action name for the transaction.
      #   The action name is required to be set for the transaction to be
      #   reported.
      #   The argument can be set to `nil` or `:set_later` if the action is set
      #   within the block with {#set_action}.
      #   This will not update the active transaction's action if
      #   {.monitor} is called when another transaction is already active.
      # @yield The block to monitor.
      # @raise [Exception] Any exception that occurs within the given block is
      #   re-raised by this method.
      # @return [Object] The value of the given block is returned.
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/background-jobs.html
      #   Monitor guide
      def monitor(action:, namespace: nil)
        return yield unless active?

        has_parent_transaction = Appsignal::Transaction.current?
        if has_parent_transaction
          callers = caller
          Appsignal::Utils::StdoutAndLoggerMessage.warning \
            "A transaction is active around this 'Appsignal.monitor' call. " \
              "Calling `Appsignal.monitor` in another `Appsignal.monitor` block has no effect. " \
              "The namespace and action are not updated for the active transaction." \
              "Did you mean to use `Appsignal.instrument`? " \
              "Update the 'Appsignal.monitor' call in: #{callers.first}"
          return yield if block_given?

          return
        end

        transaction =
          if has_parent_transaction
            Appsignal::Transaction.current
          else
            Appsignal::Transaction.create(namespace || Appsignal::Transaction::HTTP_REQUEST)
          end

        begin
          yield if block_given?
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil(action.to_s) if action && action != :set_later
          Appsignal::Transaction.complete_current!
        end
      end

      # Instrument a block of code and stop AppSignal.
      #
      # Useful for cases such as one-off scripts where there is no long running
      # process active and the data needs to be sent after the process exists.
      #
      # Acts the same way as {.monitor}. See that method for more
      # documentation.
      #
      # @see monitor
      def monitor_and_stop(action:, namespace: nil, &block)
        monitor(:namespace => namespace, :action => action, &block)
      ensure
        Appsignal.stop("monitor_and_stop")
      end

      # Send an error to AppSignal regardless of the context.
      #
      # **We recommend using the {#report_error} helper instead.**
      #
      # Records and send the exception to AppSignal.
      #
      # This instrumentation helper does not require a transaction to be
      # active, it starts a new transaction by itself.
      #
      # Use {.set_error} if your want to add an exception to the current
      # transaction.
      #
      # **Note**: Does not do anything if AppSignal is not active or when the
      # "error" is not a class extended from Ruby's Exception class.
      #
      # @example Send an exception
      #   begin
      #     raise "oh no!"
      #   rescue => e
      #     Appsignal.send_error(e)
      #   end
      #
      # @example Add more metadata to transaction
      #   Appsignal.send_error(e) do
      #     Appsignal.set_namespace("my_namespace")
      #     Appsignal.set_action("my_action_name")
      #     Appsignal.add_params(:search_query => params[:search_query])
      #     Appsignal.add_tags(:key => "value")
      #   end
      #
      # @since 0.6.0
      # @param error [Exception] The error to send to AppSignal.
      # @yield [transaction] yields block to allow modification of the
      #   transaction before it's send.
      # @yieldparam transaction [Transaction] yields the AppSignal transaction
      #   used to send the error.
      # @return [void]
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/exception-handling.html
      #   Exception handling guide
      def send_error(error, &block)
        return unless active?

        unless error.is_a?(Exception)
          internal_logger.error "Appsignal.send_error: Cannot send error. " \
            "The given value is not an exception: #{error.inspect}"
          return
        end

        transaction =
          Appsignal::Transaction.new(Appsignal::Transaction::HTTP_REQUEST)
        transaction.set_error(error, &block)

        transaction.complete
      end
      alias :send_exception :send_error

      # Set an error on the current transaction.
      #
      # **We recommend using the {#report_error} helper instead.**
      #
      # **Note**: Does not do anything if AppSignal is not active, no
      # transaction is currently active or when the "error" is not a class
      # extended from Ruby's Exception class.
      #
      # @example Manual instrumentation of set_error.
      #   # Manually starting AppSignal here
      #   # Manually starting a transaction here.
      #   begin
      #     raise "oh no!"
      #   rescue => e
      #     Appsignal.set_error(e)
      #   end
      #   # Manually completing the transaction here.
      #   # Manually stopping AppSignal here
      #
      # @example In a Rails application
      #   class SomeController < ApplicationController
      #     # The AppSignal transaction is created by our integration for you.
      #     def create
      #       # Do something that breaks
      #     rescue => e
      #       Appsignal.set_error(e)
      #     end
      #   end
      #
      # @example Add more metadata to transaction
      #   Appsignal.set_error(e) do
      #     Appsignal.set_namespace("my_namespace")
      #     Appsignal.set_action("my_action_name")
      #     Appsignal.add_params(:search_query => params[:search_query])
      #     Appsignal.add_tags(:key => "value")
      #   end
      #
      # @since 0.6.6
      # @param exception [Exception] The error to add to the current
      #   transaction.
      # @yield [transaction] yields block to allow modification of the
      #   transaction.
      # @yieldparam transaction [Transaction] yields the AppSignal transaction
      #   used to store the error.
      # @return [void]
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/exception-handling.html
      #   Exception handling guide
      def set_error(exception)
        unless exception.is_a?(Exception)
          internal_logger.error "Appsignal.set_error: Cannot set error. " \
            "The given value is not an exception: #{exception.inspect}"
          return
        end
        return if !active? || !Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_error(exception)
        yield transaction if block_given?
      end
      alias :set_exception :set_error
      alias :add_exception :set_error

      # Report an error to AppSignal.
      #
      # If a transaction is currently active, it will report the error on the
      # current transaction. If no transaction is active, it will report the
      # error on a new transaction.
      #
      # If a transaction is active and the transaction already has an error
      # reported on it, it will report multiple errors, up to a maximum of 10
      # errors.
      #
      # If a block is given to this method, the metadata set in this block will
      # only be applied to the transaction created for the given error. The
      # block will be called when the transaction is completed, which can be
      # much later than when {#report_error} is called.
      #
      # **Note**: If AppSignal is not active, no error is reported.
      #
      # **Note**: If the given exception argument is not an Exception subclass,
      # it will not be reported.
      #
      # @example
      #   class SomeController < ApplicationController
      #     def create
      #       # Do something that breaks
      #     rescue => error
      #       Appsignal.report_error(error)
      #     end
      #   end
      #
      # @example Add more metadata to transaction
      #   Appsignal.report_error(error) do
      #     Appsignal.set_namespace("my_namespace")
      #     Appsignal.set_action("my_action_name")
      #     Appsignal.add_params(:search_query => params[:search_query])
      #     Appsignal.add_tags(:key => "value")
      #   end
      #
      # @since 4.0.0
      # @param exception [Exception] The error to add to the current
      #   transaction.
      # @yield [transaction] yields block to allow modification of the
      #   transaction.
      # @yieldparam transaction [Transaction] yields the AppSignal transaction
      #   used to report the error.
      # @return [void]
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/exception-handling.html
      #   Exception handling guide
      def report_error(exception, &block)
        unless exception.is_a?(Exception)
          internal_logger.error "Appsignal.report_error: Cannot add error. " \
            "The given value is not an exception: #{exception.inspect}"
          return
        end
        return unless active?

        has_parent_transaction = Appsignal::Transaction.current?
        transaction =
          if has_parent_transaction
            Appsignal::Transaction.current
          else
            Appsignal::Transaction.new(Appsignal::Transaction::HTTP_REQUEST)
          end

        transaction.add_error(exception, &block)

        transaction.complete unless has_parent_transaction
      end
      alias :report_exception :report_error

      # Set a custom action name for the current transaction.
      #
      # When using an integration such as the Rails or Sinatra AppSignal will
      # try to find the action name from the controller or endpoint for you.
      #
      # If you want to customize the action name as it appears on AppSignal.com
      # you can use this method. This overrides the action name AppSignal
      # generates in an integration.
      #
      # @example in a Rails controller
      #   class SomeController < ApplicationController
      #     before_action :set_appsignal_action
      #
      #     def set_appsignal_action
      #       Appsignal.set_action("DynamicController#dynamic_method")
      #     end
      #   end
      #
      # @since 2.2.0
      # @param action [String]
      # @return [void]
      def set_action(action)
        return if !active? ||
          !Appsignal::Transaction.current? ||
          action.nil?

        Appsignal::Transaction.current.set_action(action)
      end

      # Set a custom namespace for the current transaction.
      #
      # When using an integration such as Rails or Sidekiq AppSignal will try
      # to find a appropriate namespace for the transaction.
      #
      # A Rails controller will be automatically put in the "http_request"
      # namespace, while a Sidekiq background job is put in the
      # "background_job" namespace.
      #
      # Note: The "http_request" namespace gets transformed on AppSignal.com to
      # "Web" and "background_job" gets transformed to "Background".
      #
      # If you want to customize the namespace in which transactions appear you
      # can use this method. This overrides the namespace AppSignal uses by
      # default.
      #
      # A common request we've seen is to split the administration panel from
      # the main application.
      #
      # @example create a custom admin namespace
      #   class AdminController < ApplicationController
      #     before_action :set_appsignal_namespace
      #
      #     def set_appsignal_namespace
      #       Appsignal.set_namespace("admin")
      #     end
      #   end
      #
      # @since 2.2.0
      # @param namespace [String]
      # @return [void]
      #
      # @see https://docs.appsignal.com/guides/namespaces.html
      #   Grouping with namespaces guide
      def set_namespace(namespace)
        return if !active? ||
          !Appsignal::Transaction.current? ||
          namespace.nil?

        Appsignal::Transaction.current.set_namespace(namespace)
      end

      # Add custom data to the current transaction.
      #
      # Add extra information about the request or background that cannot be
      # expressed in tags, like nested data structures.
      #
      # If the root data type changes between calls of this method, the last
      # method call is stored.
      #
      # @example Add Hash data
      #   Appsignal.add_custom_data(:user => { :locale => "en" })
      #
      # @example Merges Hash data
      #   Appsignal.add_custom_data(:abc => "def")
      #   Appsignal.add_custom_data(:xyz => "...")
      #   # The custom data is: { :abc => "def", :xyz => "..." }
      #
      # @example Add Array data
      #   Appsignal.add_custom_data([
      #     "array with data",
      #     "other value",
      #     :options => { :verbose => true }
      #   ])
      #
      # @example Merges Array data
      #   Appsignal.add_custom_data([1, 2, 3])
      #   Appsignal.add_custom_data([4, 5, 6])
      #   # The custom data is: [1, 2, 3, 4, 5, 6]
      #
      # @example Mixing of root data types is not supported
      #   Appsignal.add_custom_data(:abc => "def")
      #   Appsignal.add_custom_data([1, 2, 3])
      #   # The custom data is: [1, 2, 3]
      #
      # @since 4.0.0
      # @param data [Hash/Array] Custom data to add to the transaction.
      # @return [void]
      #
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      def add_custom_data(data)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_custom_data(data)
      end
      alias :set_custom_data :add_custom_data

      # Add tags to the current transaction.
      #
      # Tags are extra bits of information that are added to transaction and
      # appear on sample details pages on AppSignal.com.
      #
      # When this method is called multiple times, it will merge the tags.
      #
      # @example
      #   Appsignal.add_tags(:locale => "en", :user_id => 1)
      #   Appsignal.add_tags("locale" => "en")
      #   Appsignal.add_tags("user_id" => 1)
      #
      # @example Nested hashes are not supported
      #   # Bad
      #   Appsignal.add_tags(:user => { :locale => "en" })
      #
      # @example in a Rails controller
      #   class SomeController < ApplicationController
      #     before_action :add_appsignal_tags
      #
      #     def add_appsignal_tags
      #       Appsignal.add_tags(:locale => I18n.locale)
      #     end
      #   end
      #
      # @since 4.0.0
      # @param tags [Hash] Collection of tags to add to the transaction.
      # @option tags [String, Symbol, Integer] :any
      #   The name of the tag as a Symbol.
      # @option tags [String, Symbol, Integer] "any"
      #   The name of the tag as a String.
      # @return [void]
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
      #   Tagging guide
      def add_tags(tags = {})
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_tags(tags)
      end
      alias :tag_request :add_tags
      alias :tag_job :add_tags
      alias :set_tags :add_tags

      # Add parameters to the current transaction.
      #
      # Parameters are automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different parameters.
      #
      # To filter parameters, see our parameter filtering guide.
      #
      # When both the `params` argument and a block is given to this method,
      # the block is leading and the argument will _not_ be used.
      #
      # @example Add parameters
      #   Appsignal.add_params("param1" => "value1")
      #   # The parameters include: { "param1" => "value1" }
      #
      # @example Calling `add_params` multiple times will merge the values
      #   Appsignal.add_params("param1" => "value1")
      #   Appsignal.add_params("param2" => "value2")
      #   # The parameters include:
      #   # { "param1" => "value1", "param2" => "value2" }
      #
      # @since 4.0.0
      # @param params [Hash] The parameters to add to the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new parameters.
      # @return [void]
      #
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-parameters.html
      #   Parameter filtering guide
      def add_params(params = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_params(params, &block)
      end
      alias :set_params :add_params

      # Mark the parameters sample data to be set as an empty value.
      #
      # Use this helper to unset request parameters / background job arguments
      # and not report any for this transaction.
      #
      # If parameters would normally be added by AppSignal instrumentations of
      # libraries, these parameters will not be added to the Transaction.
      #
      # Calling {#add_params} after this helper will add new parameters to the
      # transaction.
      #
      # @since 4.2.0
      # @return [void]
      #
      # @see Transaction#set_empty_params!
      # @see Transaction#set_params_if_nil
      def set_empty_params!
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_empty_params!
      end

      # Add session data to the current transaction.
      #
      # Session data is automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different session data.
      #
      # To filter session data, see our session data filtering guide.
      #
      # When both the `session_data` argument and a block is given to this
      # method, the bock is leading and the argument will _not_ be used.
      #
      # @example Add session data
      #   Appsignal.add_session_data("session" => "data")
      #   # The session data will include:
      #   # { "session" => "data" }
      #
      # @example Calling `add_session_data` multiple times merge the values
      #   Appsignal.add_session_data("session" => "data")
      #   Appsignal.add_session_data("other" => "value")
      #   # The session data will include:
      #   # { "session" => "data", "other" => "value" }
      #
      # @since 4.0.0
      # @param session_data [Hash] The session data to add to the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new session data.
      # @return [void]
      #
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-session-data.html
      #   Session data filtering guide
      def add_session_data(session_data = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_session_data(session_data, &block)
      end
      alias :set_session_data :add_session_data

      # Add request headers to the current transaction.
      #
      # Request headers are automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to also
      # report different request headers.
      #
      # To filter request headers, see our request header filtering guide.
      #
      # When both the `request_headers` argument and a block is given to this
      # method, the block is leading and the argument will _not_ be used.
      #
      # @example Add request headers
      #   Appsignal.add_headers("PATH_INFO" => "/some-path")
      #   # The request headers will include:
      #   # { "PATH_INFO" => "/some-path" }
      #
      # @example Calling `add_headers` multiple times merge the values
      #   Appsignal.add_headers("PATH_INFO" => "/some-path")
      #   Appsignal.add_headers("HTTP_USER_AGENT" => "Firefox")
      #   # The request headers will include:
      #   # { "PATH_INFO" => "/some-path", "HTTP_USER_AGENT" => "Firefox" }
      #
      # @since 4.0.0
      # @param headers [Hash] The request headers to add to the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new request headers.
      # @return [void]
      #
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-headers.html
      #   Request headers filtering guide
      def add_headers(headers = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_headers(headers, &block)
      end
      alias :set_headers :add_headers

      # Add breadcrumbs to the transaction.
      #
      # Breadcrumbs can be used to trace what path a user has taken
      # before encounterin an error.
      #
      # Only the last 20 added breadcrumbs will be saved.
      #
      # @example
      #   Appsignal.add_breadcrumb(
      #     "Navigation",
      #     "http://blablabla.com",
      #     "",
      #     { :response => 200 },
      #     Time.now.utc
      #   )
      #   Appsignal.add_breadcrumb(
      #     "Network",
      #     "[GET] http://blablabla.com",
      #     "",
      #     { :response => 500 }
      #   )
      #   Appsignal.add_breadcrumb(
      #     "UI",
      #     "closed modal(change_password)",
      #     "User closed modal without actions"
      #   )
      #
      # @since 2.12.0
      # @param category [String] category of breadcrumb
      #   e.g. "UI", "Network", "Navigation", "Console".
      # @param action [String] name of breadcrumb
      #   e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
      # @option message [String]  optional message in string format
      # @option metadata [Hash<String,String>]  key/value metadata in <string, string> format
      # @option time [Time] time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
      # @return [void]
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html
      #   Breadcrumb reference
      def add_breadcrumb(category, action, message = "", metadata = {}, time = Time.now.utc)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.add_breadcrumb(category, action, message, metadata, time)
      end

      # Instrument helper for AppSignal.
      #
      # For more help, read our custom instrumentation guide, listed under "See
      # also".
      #
      # @example Simple instrumentation
      #   Appsignal.instrument("fetch.issue_fetcher") do
      #     # To be instrumented code
      #   end
      #
      # @example Instrumentation with title and body
      #   Appsignal.instrument(
      #     "fetch.issue_fetcher",
      #     "Fetching issue",
      #     "GitHub API"
      #   ) do
      #     # To be instrumented code
      #   end
      #
      # @since 1.3.0
      # @param name [String] Name of the instrumented event. Read our event
      #   naming guide listed under "See also".
      # @param title [String, nil] Human readable name of the event.
      # @param body [String, nil] Value of importance for the event, such as
      #   the server against an API call is made.
      # @param body_format [Integer] Enum for the type of event that is
      #   instrumented. Accepted values are {EventFormatter::DEFAULT} and
      #   {EventFormatter::SQL_BODY_FORMAT}, but we recommend you use
      #   {.instrument_sql} instead of {EventFormatter::SQL_BODY_FORMAT}.
      # @yield yields the given block of code instrumented in an AppSignal
      #   event.
      # @return [Object] Returns the block's return value.
      #
      # @see .instrument_sql
      # @see https://docs.appsignal.com/ruby/instrumentation/instrumentation.html
      #   AppSignal custom instrumentation guide
      # @see https://docs.appsignal.com/api/event-names.html
      #   AppSignal event naming guide
      def instrument(
        name,
        title = nil,
        body = nil,
        body_format = Appsignal::EventFormatter::DEFAULT,
        &block
      )
        Appsignal::Transaction.current
          .instrument(name, title, body, body_format, &block)
      end

      # Instrumentation helper for SQL queries.
      #
      # This helper filters out values from SQL queries so you don't have to.
      #
      # @example SQL query instrumentation
      #   body = "SELECT * FROM ..."
      #   Appsignal.instrument_sql("perform.query", nil, body) do
      #     # To be instrumented code
      #   end
      #
      # @example SQL query instrumentation
      #   body = "WHERE email = 'foo@..'"
      #   Appsignal.instrument_sql("perform.query", nil, body) do
      #     # query value will replace 'foo..' with a question mark `?`.
      #   end
      #
      # @since 2.0.0
      # @param name [String] Name of the instrumented event. Read our event
      #   naming guide listed under "See also".
      # @param title [String, nil] Human readable name of the event.
      # @param body [String, nil] SQL query that's being executed.
      # @yield yields the given block of code instrumented in an AppSignal
      #   event.
      # @return [Object] Returns the block's return value.
      #
      # @see .instrument
      # @see https://docs.appsignal.com/ruby/instrumentation/instrumentation.html
      #   AppSignal custom instrumentation guide
      # @see https://docs.appsignal.com/api/event-names.html
      #   AppSignal event naming guide
      def instrument_sql(name, title = nil, body = nil, &block)
        instrument(
          name,
          title,
          body,
          Appsignal::EventFormatter::SQL_BODY_FORMAT,
          &block
        )
      end

      # Convenience method for ignoring instrumentation events in a block of
      # code.
      #
      # - This helper ignores events, like those created
      #   `Appsignal.instrument`, within this block.
      #   This includes custom instrumentation and events recorded by AppSignal
      #   integrations for requests, database queries, view rendering, etc.
      # - The time spent in the block is still reported on the transaction.
      # - Errors and metrics are reported from within this block.
      #
      # @example
      #   Appsignal.instrument "my_event.my_group" do
      #     # Complex code here
      #   end
      #   Appsignal.ignore_instrumentation_events do
      #     Appsignal.instrument "my_ignored_event.my_ignored_group" do
      #       # Complex code here
      #     end
      #   end
      #
      #   # Only the "my_event.my_group" instrumentation event is reported.
      #
      # @since 3.10.0
      # @yield block of code that shouldn't be instrumented.
      # @return [Object] Returns the return value of the block.
      #
      # @see https://docs.appsignal.com/ruby/instrumentation/ignore-instrumentation.html
      #   Ignore instrumentation guide
      def ignore_instrumentation_events
        Appsignal::Transaction.current&.pause!
        yield
      ensure
        Appsignal::Transaction.current&.resume!
      end
    end
  end
end
