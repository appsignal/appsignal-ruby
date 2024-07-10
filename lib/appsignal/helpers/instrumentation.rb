# frozen_string_literal: true

module Appsignal
  module Helpers
    module Instrumentation
      include Appsignal::Utils::StdoutAndLoggerMessage

      # Creates an AppSignal transaction for the given block.
      #
      # If AppSignal is not {Appsignal.active?} it will still execute the
      # block, but not create a transaction for it.
      #
      # A event is created for this transaction with the name given in the
      # `name` argument. The event name must start with either `perform_job` or
      # `process_action` to differentiate between the "web" and "background"
      # namespace. Custom namespaces are not supported by this helper method.
      #
      # This helper method also captures any exception that occurs in the given
      # block.
      #
      # @example
      #   Appsignal.monitor_transaction("perform_job.nightly_update") do
      #     # your code
      #   end
      #
      # @example with an environment
      #   Appsignal.monitor_transaction(
      #     "perform_job.nightly_update",
      #     :metadata => { "user_id" => 1 }
      #   ) do
      #     # your code
      #   end
      #
      # @param name [String] main event name.
      # @param env [Hash<Symbol, Object>]
      # @option env [Hash<Symbol/String, Object>] :params Params for the
      #   monitored request/job, see {Appsignal::Transaction#params=} for more
      #   information.
      # @option env [String] :controller name of the controller in which the
      #   transaction was recorded.
      # @option env [String] :class name of the Ruby class in which the
      #   transaction was recorded. If `:controller` is also given,
      #   `:controller` is used instead.
      # @option env [String] :action name of the controller action in which the
      #   transaction was recorded.
      # @option env [String] :method name of the Ruby method in which the
      #   transaction was recorded. If `:action` is also given, `:action`
      #   is used instead.
      # @option env [Integer] :queue_start the moment the request/job was
      #   queued. Used to track how long requests/jobs were queued before being
      #   executed.
      # @option env [Hash<Symbol/String, String/Fixnum>] :metadata Additional
      #   metadata for the transaction, see
      #   {Appsignal::Transaction#set_metadata} for more information.
      # @yield the block to monitor.
      # @raise [Exception] any exception that occurs within the given block is
      #   re-raised by this method.
      # @return [Object] the value of the given block is returned.
      # @since 0.10.0
      def monitor_transaction(name, env = {}, &block)
        # Always verify input, even when Appsignal is not active.
        # This makes it more likely invalid arguments get flagged in test/dev
        # environments.
        if name.start_with?("perform_job")
          namespace = Appsignal::Transaction::BACKGROUND_JOB
          request   = Appsignal::Transaction::GenericRequest.new(env)
        elsif name.start_with?("process_action")
          namespace = Appsignal::Transaction::HTTP_REQUEST
          request   = ::Rack::Request.new(env)
        else
          internal_logger.error "Unrecognized name '#{name}': names must " \
            "start with either 'perform_job' (for jobs and tasks) or " \
            "'process_action' (for HTTP requests)"
          return yield
        end

        return yield unless active?

        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          namespace,
          request
        )
        begin
          Appsignal.instrument(name, &block)
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_http_or_background_action(request.env)
          queue_start = Appsignal::Rack::Utils.queue_start_from(request.env) ||
            (env[:queue_start]&.to_i&.* 1_000)
          transaction.set_queue_start(queue_start) if queue_start
          Appsignal::Transaction.complete_current!
        end
      end

      # Monitor a transaction, stop AppSignal and wait for this single
      # transaction to be flushed.
      #
      # Useful for cases such as Rake tasks and Resque-like systems where a
      # process is forked and immediately exits after the transaction finishes.
      #
      # @see monitor_transaction
      def monitor_single_transaction(name, env = {}, &block)
        monitor_transaction(name, env, &block)
      ensure
        stop("monitor_single_transaction")
      end

      # Listen for an error to occur and send it to AppSignal.
      #
      # Uses {.send_error} to directly send the error in a separate
      # transaction. Does not add the error to the current transaction.
      #
      # Make sure that AppSignal is integrated in your application beforehand.
      # AppSignal won't record errors unless {Appsignal.active?} is `true`.
      #
      # @example
      #   # my_app.rb
      #   # setup AppSignal beforehand
      #
      #   Appsignal.listen_for_error do
      #     # my code
      #     raise "foo"
      #   end
      #
      # @see Transaction.set_tags
      # @see Transaction.set_namespace
      # @see .send_error
      # @see https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html
      #   AppSignal integration guide
      #
      # @param tags [Hash, nil]
      # @param namespace [String] the namespace for this error.
      # @yield yields the given block.
      # @return [Object] returns the return value of the given block.
      def listen_for_error(
        tags = nil,
        namespace = Appsignal::Transaction::HTTP_REQUEST
      )
        yield
      rescue Exception => error # rubocop:disable Lint/RescueException
        send_error(error) do |transaction|
          transaction.set_tags(tags) if tags
          transaction.set_namespace(namespace) if namespace
        end
        raise error
      end
      alias :listen_for_exception :listen_for_error

      # Send an error to AppSignal regardless of the context.
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
      # @example Send an exception with tags. Deprecated method.
      #   begin
      #     raise "oh no!"
      #   rescue => e
      #     Appsignal.send_error(e, :key => "value")
      #   end
      #
      # @example Add more metadata to transaction
      #   Appsignal.send_error(e) do |transaction|
      #     transaction.set_params(:search_query => params[:search_query])
      #     transaction.set_action("my_action_name")
      #     transaction.set_tags(:key => "value")
      #     transaction.set_namespace("my_namespace")
      #   end
      #
      # @param error [Exception] The error to send to AppSignal.
      # @param tags [Hash{String, Symbol => String, Symbol, Integer}]
      #   Additional tags to add to the error. See also {.tag_request}.
      #   This parameter is deprecated. Use the block argument instead.
      # @param namespace [String] The namespace in which the error occurred.
      #   See also {.set_namespace}.
      #   This parameter is deprecated. Use the block argument instead.
      # @yield [transaction] yields block to allow modification of the
      #   transaction before it's send.
      # @yieldparam transaction [Transaction] yields the AppSignal transaction
      #   used to send the error.
      # @return [void]
      #
      # @see Transaction#report_error
      # @see https://docs.appsignal.com/ruby/instrumentation/exception-handling.html
      #   Exception handling guide
      # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
      #   Tagging guide
      # @since 0.6.0
      def send_error(
        error,
        tags = nil,
        namespace = nil
      )
        if tags
          call_location = caller(1..1).first
          stdout_and_logger_warning \
            "The tags argument for `Appsignal.send_error` is deprecated. " \
              "Please use the block method to set tags instead.\n\n" \
              "  Appsignal.send_error(error) do |transaction|\n" \
              "    transaction.set_tags(#{tags})\n" \
              "  end\n\n" \
              "Appsignal.send_error called on location: #{call_location}"
        end
        if namespace
          call_location = caller(1..1).first
          stdout_and_logger_warning \
            "The namespace argument for `Appsignal.send_error` is deprecated. " \
              "Please use the block method to set the namespace instead.\n\n" \
              "  Appsignal.send_error(error) do |transaction|\n" \
              "    transaction.set_namespace(#{namespace.inspect})\n" \
              "  end\n\n" \
              "Appsignal.send_error called on location: #{call_location}"
        end
        return unless active?

        unless error.is_a?(Exception)
          internal_logger.error "Appsignal.send_error: Cannot send error. " \
            "The given value is not an exception: #{error.inspect}"
          return
        end
        transaction = Appsignal::Transaction.new(
          SecureRandom.uuid,
          namespace || Appsignal::Transaction::HTTP_REQUEST,
          Appsignal::Transaction::GenericRequest.new({})
        )
        transaction.set_tags(tags) if tags
        transaction.set_error(error)
        yield transaction if block_given?
        transaction.complete
      end
      alias :send_exception :send_error

      # Set an error on the current transaction.
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
      #   Appsignal.set_error(e) do |transaction|
      #     transaction.set_params(:search_query => params[:search_query])
      #     transaction.set_action("my_action_name")
      #     transaction.set_tags(:key => "value")
      #     transaction.set_namespace("my_namespace")
      #   end
      #
      # @param exception [Exception] The error to add to the current
      #   transaction.
      # @param tags [Hash{String, Symbol => String, Symbol, Integer}]
      #   Additional tags to add to the error. See also {.tag_request}.
      #   This parameter is deprecated. Use the block argument instead.
      # @param namespace [String] The namespace in which the error occurred.
      #   See also {.set_namespace}.
      #   This parameter is deprecated. Use the block argument instead.
      # @yield [transaction] yields block to allow modification of the
      #   transaction.
      # @yieldparam transaction [Transaction] yields the AppSignal transaction
      #   used to store the error.
      # @return [void]
      #
      # @see Transaction#set_error
      # @see Transaction#report_error
      # @see https://docs.appsignal.com/ruby/instrumentation/exception-handling.html
      #   Exception handling guide
      # @since 0.6.6
      def set_error(exception, tags = nil, namespace = nil)
        if tags
          call_location = caller(1..1).first
          stdout_and_logger_warning \
            "The tags argument for `Appsignal.set_error` is deprecated. " \
              "Please use the block method to set tags instead.\n\n" \
              "  Appsignal.set_error(error) do |transaction|\n" \
              "    transaction.set_tags(#{tags})\n" \
              "  end\n\n" \
              "Appsignal.set_error called on location: #{call_location}"
        end
        if namespace
          call_location = caller(1..1).first
          stdout_and_logger_warning \
            "The namespace argument for `Appsignal.set_error` is deprecated. " \
              "Please use the block method to set the namespace instead.\n\n" \
              "  Appsignal.set_error(error) do |transaction|\n" \
              "    transaction.set_namespace(#{namespace.inspect})\n" \
              "  end\n\n" \
              "Appsignal.set_error called on location: #{call_location}"
        end
        unless exception.is_a?(Exception)
          internal_logger.error "Appsignal.set_error: Cannot set error. " \
            "The given value is not an exception: #{exception.inspect}"
          return
        end
        return if !active? || !Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_error(exception)
        transaction.set_tags(tags) if tags
        transaction.set_namespace(namespace) if namespace
        yield transaction if block_given?
      end
      alias :set_exception :set_error
      alias :add_exception :set_error

      # Report an error.
      #
      # If a transaction is currently active, it will report the error on the
      # current transaction. If no transaction is active, it will report the
      # error on a new transaction.
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
      #   Appsignal.report_error(error) do |transaction|
      #     transaction.set_namespace("my_namespace")
      #     transaction.set_action("my_action_name")
      #     transaction.set_params(:search_query => params[:search_query])
      #     transaction.set_tags(:key => "value")
      #   end
      #
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
      # @since 3.10.0
      def report_error(exception)
        unless exception.is_a?(Exception)
          internal_logger.error "Appsignal.report_error: Cannot set error. " \
            "The given value is not an exception: #{exception.inspect}"
          return
        end
        return unless active?

        has_parent_transaction = Appsignal::Transaction.current?
        transaction =
          if has_parent_transaction
            Appsignal::Transaction.current
          else
            Appsignal::Transaction.new(
              SecureRandom.uuid,
              Appsignal::Transaction::HTTP_REQUEST,
              Appsignal::Transaction::GenericRequest.new({})
            )
          end

        transaction.set_error(exception)
        yield transaction if block_given?

        return if has_parent_transaction

        transaction.complete
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
      # @param action [String]
      # @return [void]
      # @see Transaction#set_action
      # @since 2.2.0
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
      # @param namespace [String]
      # @return [void]
      # @see Transaction#set_namespace
      # @since 2.2.0
      def set_namespace(namespace)
        return if !active? ||
          !Appsignal::Transaction.current? ||
          namespace.nil?

        Appsignal::Transaction.current.set_namespace(namespace)
      end

      # Set custom data on the current transaction.
      #
      # Add extra information about the request or background that cannot be
      # expressed in tags, like nested data structures.
      #
      # When this method is called multiple times, it will overwrite the
      # previously set value.
      #
      # @example
      #   Appsignal.set_custom_data(:user => { :locale => "en" })
      #   Appsignal.set_custom_data([
      #     "array with data",
      #     :options => { :verbose => true }
      #   ])
      #
      # @since 3.10.0
      # @see Transaction#set_custom_data
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @param data [Hash/Array]
      # @return [void]
      def set_custom_data(data)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_custom_data(data)
      end

      # Set tags on the current transaction.
      #
      # Tags are extra bits of information that are added to transaction and
      # appear on sample details pages on AppSignal.com.
      #
      # When this method is called multiple times, it will merge the tags.
      #
      # @example
      #   Appsignal.tag_request(:locale => "en", :user_id => 1)
      #   Appsignal.tag_request("locale" => "en")
      #   Appsignal.tag_request("user_id" => 1)
      #
      # @example Nested hashes are not supported
      #   # Bad
      #   Appsignal.tag_request(:user => { :locale => "en" })
      #
      # @example in a Rails controller
      #   class SomeController < ApplicationController
      #     before_action :set_appsignal_tags
      #
      #     def set_appsignal_tags
      #       Appsignal.tag_request(:locale => I18n.locale)
      #     end
      #   end
      #
      # @param tags [Hash] Collection of tags.
      # @option tags [String, Symbol, Integer] :any
      #   The name of the tag as a Symbol.
      # @option tags [String, Symbol, Integer] "any"
      #   The name of the tag as a String.
      # @return [void]
      #
      # @see Transaction.set_tags
      # @see https://docs.appsignal.com/ruby/instrumentation/tagging.html
      #   Tagging guide
      def tag_request(tags = {})
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_tags(tags)
      end
      alias :tag_job :tag_request
      alias :set_tags :tag_request

      # Set parameters on the current transaction.
      #
      # Parameters are automatically set by most of our integrations. It should
      # not be necessary to call this method unless you want to report
      # different parameters.
      #
      # To filter parameters, see our parameter filtering guide.
      #
      # When this method is called multiple times, it will overwrite the
      # previously set value.
      #
      # When no parameters are set this way, the transaction will look for
      # parameters in its request environment.
      #
      # A block can be given to this method to defer the fetching and parsing
      # of the parameters until and only when the transaction is sampled.
      #
      # When both the `params` argument and a block is given to this method,
      # the `params` argument is leading and the block will _not_ be called.
      #
      # @example Set parameters
      #   Appsignal.set_params("param1" => "value1")
      #
      # @example Calling `set_params` multiple times will only keep the last call
      #   Appsignal.set_params("param1" => "value1")
      #   Appsignal.set_params("param2" => "value2")
      #   # The parameters are: { "param2" => "value2" }
      #
      # @example Calling `set_params` with a block
      #   Appsignal.set_params do
      #     # Some slow code to parse parameters
      #     JSON.parse('{"param1": "value1"}')
      #   end
      #   # The parameters are: { "param1" => "value1" }
      #
      # @example Calling `set_params` with a parameter and a block
      #   Appsignal.set_params("argument" => "argument value") do
      #     # Some slow code to parse parameters
      #     JSON.parse('{"param1": "value1"}')
      #   end
      #   # The parameters are: { "argument" => "argument value" }
      #
      # @since 3.10.0
      # @param params [Hash] The parameters to set on the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new parameters.
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-parameters.html
      #   Parameter filtering guide
      # @see Transaction#set_params
      # @return [void]
      def set_params(params = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_params(params, &block)
      end

      # Set session data on the current transaction.
      #
      # Session data is automatically set by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different session data.
      #
      # To filter session data, see our session data filtering guide.
      #
      # When this method is called multiple times, it will overwrite the
      # previously set value.
      #
      # A block can be given to this method to defer the fetching and parsing
      # of the session data until and only when the transaction is sampled.
      #
      # When both the `session_data` argument and a block is given to this
      # method, the `session_data` argument is leading and the block will _not_
      # be called.
      #
      # @example Set session data
      #   Appsignal.set_session_data("data" => "value")
      #
      # @example Calling `set_session_data` multiple times will only keep the last call
      #   Appsignal.set_session_data("data1" => "value1")
      #   Appsignal.set_session_data("data2" => "value2")
      #   # The session data is: { "data2" => "value2" }
      #
      # @example Calling `set_session_data` with a block
      #   Appsignal.set_session_data do
      #     # Some slow code to parse session data
      #     JSON.parse('{"data": "value"}')
      #   end
      #   # The session data is: { "data" => "value" }
      #
      # @example Calling `set_session_data` with a session_data argument and a block
      #   Appsignal.set_session_data("argument" => "argument value") do
      #     # Some slow code to parse session data
      #     JSON.parse('{"data": "value"}')
      #   end
      #   # The session data is: { "argument" => "argument value" }
      #
      # @since 3.11.0
      # @param session_data [Hash] The session data to set on the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new session data.
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-session-data.html
      #   Session data filtering guide
      # @see Transaction#set_session_data
      # @return [void]
      def set_session_data(session_data = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_session_data(session_data, &block)
      end

      # Set request headers on the current transaction.
      #
      # Request headers are automatically set by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different request headers.
      #
      # To filter request headers, see our session data filtering guide.
      #
      # When this method is called multiple times, it will overwrite the
      # previously set value.
      #
      # A block can be given to this method to defer the fetching and parsing
      # of the request headers until and only when the transaction is sampled.
      #
      # When both the `request_headers` argument and a block is given to this
      # method, the `request_headers` argument is leading and the block will
      # _not_ be called.
      #
      # @example Set request headers
      #   Appsignal.set_headers(
      #     "PATH_INFO" => "/some-path",
      #     "HTTP_USER_AGENT" => "Firefox"
      #   )
      #
      # @example Calling `set_headers` multiple times will only keep the last call
      #   Appsignal.set_headers("PATH_INFO" => "/some-path")
      #   Appsignal.set_headers("HTTP_USER_AGENT" => "Firefox")
      #   # The request headers are: { "HTTP_USER_AGENT" => "Firefox" }
      #
      # @example Calling `set_headers` with a block
      #   Appsignal.set_headers do
      #     # Some slow code to parse request headers
      #     JSON.parse('{"PATH_INFO": "/some-path"}')
      #   end
      #   # The session data is: { "PATH_INFO" => "/some-path" }
      #
      # @example Calling `set_headers` with a headers argument and a block
      #   Appsignal.set_headers("PATH_INFO" => "/some-path") do
      #     # Some slow code to parse session data
      #     JSON.parse('{"PATH_INFO": "/block-path"}')
      #   end
      #   # The session data is: { "PATH_INFO" => "/some-path" }
      #
      # @since 3.11.0
      # @param headers [Hash] The request headers to set on the transaction.
      # @yield This block is called when the transaction is sampled. The block's
      #   return value will become the new request headers.
      # @see https://docs.appsignal.com/guides/custom-data/sample-data.html
      #   Sample data guide
      # @see https://docs.appsignal.com/guides/filter-data/filter-headers.html
      #   Request headers filtering guide
      # @see Transaction#set_headers
      # @return [void]
      def set_headers(headers = nil, &block)
        return unless active?
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        transaction.set_headers(headers, &block)
      end

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
      # @param category [String] category of breadcrumb
      #   e.g. "UI", "Network", "Navigation", "Console".
      # @param action [String] name of breadcrumb
      #   e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
      # @option message [String]  optional message in string format
      # @option metadata [Hash<String,String>]  key/value metadata in <string, string> format
      # @option time [Time] time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
      # @return [void]
      #
      # @see Transaction#add_breadcrumb
      # @see https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html
      #   Breadcrumb reference
      # @since 2.12.0
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
      # @see Appsignal::Transaction#instrument
      # @see .instrument_sql
      # @see https://docs.appsignal.com/ruby/instrumentation/instrumentation.html
      #   AppSignal custom instrumentation guide
      # @see https://docs.appsignal.com/api/event-names.html
      #   AppSignal event naming guide
      # @since 1.3.0
      def instrument(
        name,
        title = nil,
        body = nil,
        body_format = Appsignal::EventFormatter::DEFAULT
      )
        Appsignal::Transaction.current.start_event
        yield if block_given?
      ensure
        Appsignal::Transaction
          .current
          .finish_event(name, title, body, body_format)
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
      # @since 2.0.0
      def instrument_sql(name, title = nil, body = nil, &block)
        instrument(
          name,
          title,
          body,
          Appsignal::EventFormatter::SQL_BODY_FORMAT,
          &block
        )
      end

      # Convenience method for skipping instrumentations around a block of code.
      #
      # @example
      #   Appsignal.without_instrumentation do
      #     # Complex code here
      #   end
      #
      # @yield block of code that shouldn't be instrumented.
      # @return [Object] Returns the return value of the block.
      # @since 0.8.7
      def without_instrumentation
        Appsignal::Transaction.current&.pause!
        yield
      ensure
        Appsignal::Transaction.current&.resume!
      end
    end
  end
end
