# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # Base instrumentation middleware.
    #
    # Do not use this middleware directly. Instead use
    # {InstrumentationMiddleware}.
    #
    # @api private
    class AbstractMiddleware
      DEFAULT_ERROR_REPORTING = :default

      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class}"
        @app = app
        @options = options
        @request_class = options.fetch(:request_class, ::Rack::Request)
        @params_method = options.fetch(:params_method, :params)
        @instrument_event_name = options.fetch(:instrument_event_name, nil)
        @report_errors = options.fetch(:report_errors, DEFAULT_ERROR_REPORTING)
      end

      def call(env)
        if Appsignal.active?
          request = request_for(env)
          # Supported nested instrumentation middlewares by checking if there's
          # already a transaction active for this request.
          wrapped_instrumentation = env.key?(Appsignal::Rack::APPSIGNAL_TRANSACTION)
          transaction =
            if wrapped_instrumentation
              env[Appsignal::Rack::APPSIGNAL_TRANSACTION]
            else
              Appsignal::Transaction.create(
                SecureRandom.uuid,
                Appsignal::Transaction::HTTP_REQUEST,
                request
              )
            end

          unless wrapped_instrumentation
            # Set transaction on the request environment so other nested
            # middleware can detect if there is parent instrumentation
            # middleware active.
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
          end

          begin
            add_transaction_metadata_before(transaction, request)
            # Report errors if the :report_errors option is set to true or when
            # there is no parent instrumentation that can rescue and report the error.
            if @report_errors || !wrapped_instrumentation
              instrument_app_call_with_exception_handling(
                request.env,
                transaction,
                wrapped_instrumentation
              )
            else
              instrument_app_call(request.env, transaction)
            end
          ensure
            add_transaction_metadata_after(transaction, request)

            # Complete transaction because this is the top instrumentation middleware.
            Appsignal::Transaction.complete_current! unless wrapped_instrumentation
          end
        else
          @app.call(env)
        end
      end

      private

      # Another instrumentation middleware is active earlier in the stack, so
      # don't report any exceptions here, the top instrumentation middleware
      # will be the one reporting the exception.
      #
      # Either another {AbstractMiddleware} or {EventHandler} is higher in the
      # stack and will report the exception and complete the transaction.
      #
      # @see {#instrument_app_call_with_exception_handling}
      def instrument_app_call(env, transaction)
        if @instrument_event_name
          Appsignal.instrument(@instrument_event_name) do
            call_app(env, transaction)
          end
        else
          call_app(env, transaction)
        end
      end

      def call_app(env, transaction)
        status, headers, obody = @app.call(env)
        body =
          if obody.is_a? Appsignal::Rack::BodyWrapper
            obody
          else
            # Instrument response body and closing of the response body
            Appsignal::Rack::BodyWrapper.wrap(obody, transaction)
          end
        [status, headers, body]
      end

      # Instrument the request fully. This is used by the top instrumentation
      # middleware in the middleware stack. Unlike
      # {#instrument_app_call} this will report any exceptions being
      # raised.
      #
      # @see {#instrument_app_call}
      def instrument_app_call_with_exception_handling(env, transaction, wrapped_instrumentation)
        instrument_app_call(env, transaction)
      rescue Exception => error # rubocop:disable Lint/RescueException
        report_errors =
          if @report_errors == DEFAULT_ERROR_REPORTING
            # If there's no parent transaction, report the error
            !wrapped_instrumentation
          elsif @report_errors.respond_to?(:call)
            # If the @report_errors option is callable, call it with the
            # request environment so it can determine if the error needs to be
            # reported.
            @report_errors.call(env)
          else
            @report_errors
          end
        transaction.set_error(error) if report_errors
        raise error
      end

      # Add metadata to the transaction based on the request environment.
      # Override this method to set metadata before the app is called.
      # Call `super` to also include the default set metadata.
      def add_transaction_metadata_before(transaction, request)
      end

      # Add metadata to the transaction based on the request environment.
      # Override this method to set metadata after the app is called.
      # Call `super` to also include the default set metadata.
      def add_transaction_metadata_after(transaction, request)
        default_action =
          appsignal_route_env_value(request) || appsignal_action_env_value(request)
        transaction.set_action_if_nil(default_action)
        transaction.set_metadata("path", request.path)

        request_method = request_method_for(request)
        transaction.set_metadata("method", request_method) if request_method

        transaction.set_params_if_nil { params_for(request) }
        transaction.set_http_or_background_queue_start
      end

      def params_for(request)
        return unless request.respond_to?(@params_method)

        request.send(@params_method)
      rescue => error
        # Getting params from the request has been know to fail.
        Appsignal.internal_logger.debug(
          "Exception while getting params in #{self.class} from '#{@params_method}': #{error}"
        )
        nil
      end

      def request_method_for(request)
        request.request_method
      rescue => error
        Appsignal.internal_logger.error("Unable to report HTTP request method: '#{error}'")
        nil
      end

      def request_for(env)
        @request_class.new(env)
      end

      def appsignal_route_env_value(request)
        request.env["appsignal.route"].tap do |value|
          next unless value

          Appsignal::Utils::StdoutAndLoggerMessage.warning \
            "Setting the action name with the request env 'appsignal.route' is deprecated. " \
              "Please use `Appsignal.set_action` instead. "
        end
      end

      def appsignal_action_env_value(request)
        request.env["appsignal.action"].tap do |value|
          next unless value

          Appsignal::Utils::StdoutAndLoggerMessage.warning \
            "Setting the action name with the request env 'appsignal.action' is deprecated. " \
              "Please use `Appsignal.set_action` instead. "
        end
      end
    end
  end
end
