# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # Base instrumentation middleware.
    #
    # Do not use this middleware directly. Instead use
    # {InstrumentationMiddleware}.
    #
    # @abstract
    # @api private
    class AbstractMiddleware
      DEFAULT_ERROR_REPORTING = :default

      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class}"
        @app = app
        @options = options
        @request_class = options.fetch(:request_class, ::Rack::Request)
        @instrument_event_name = options.fetch(:instrument_event_name, nil)
        # The OpenTelemetry instrumentation scope for the request's spans in
        # collector mode. Each framework middleware sets its own; nil falls back
        # to the default scope in the backend.
        @opentelemetry_scope = options.fetch(:opentelemetry_scope, nil)
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
                Appsignal::Transaction::HTTP_REQUEST,
                :opentelemetry_context => Appsignal::OpenTelemetry.extract_rack_context(env),
                :opentelemetry_scope => @opentelemetry_scope
              )
            end

          unless wrapped_instrumentation
            # Set transaction on the request environment so other nested
            # middleware can detect if there is parent instrumentation
            # middleware active.
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
            add_opentelemetry_request_attributes(transaction, request)
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

            unless wrapped_instrumentation
              add_opentelemetry_response_attributes(transaction, request)

              # Complete transaction because this is the top instrumentation
              # middleware.
              Appsignal::Transaction.complete_current!
            end
          end
        else
          @app.call(env)
        end
      end

      private

      # Describes the transaction's span as an incoming HTTP request. Together
      # with the SERVER span kind the transaction already carries, this is what
      # the trace timeline reads to recognize a web request.
      #
      # Set here, where the transaction is created, and not alongside the rest
      # of the request metadata in {ApplyRackRequest}. That runs after the app
      # has been called, when an event span may be open, and the attributes
      # would land on that event instead of on the transaction's own span.
      # Only the middleware that created the transaction sets them, so nested
      # middleware doesn't write them a second time onto whatever span is open
      # by then.
      def add_opentelemetry_request_attributes(transaction, request)
        transaction.add_opentelemetry_attributes(
          Appsignal::OpenTelemetry::HttpServerRequest.attributes_for(
            :method => Appsignal::Rack::Utils.request_method_from(request),
            :path => Appsignal::Rack::Utils.request_value_from(request, :path),
            :scheme => Appsignal::Rack::Utils.request_value_from(request, :scheme),
            :query => Appsignal::Rack::Utils.request_value_from(request, :query_string)
          )
        )
      end

      # Describes the response the app produced on the transaction's span, which
      # the semantic conventions ask for whenever a response was sent.
      #
      # Set from the `ensure` in {#call} rather than from {#call_app}, where the
      # status is first known. That runs inside the instrumented event, so the
      # attribute would land on the event span instead of on the transaction's
      # own span. The status travels between the two in the request environment
      # for that reason.
      #
      # A request whose app raised never produced a status, and is described
      # without one.
      def add_opentelemetry_response_attributes(transaction, request)
        transaction.add_opentelemetry_attributes(
          Appsignal::OpenTelemetry::HttpResponse.attributes_for(
            request.env[Appsignal::Rack::APPSIGNAL_RESPONSE_STATUS]
          )
        )
      end

      # Another instrumentation middleware is active earlier in the stack, so
      # don't report any exceptions here, the top instrumentation middleware
      # will be the one reporting the exception.
      #
      # Either another {AbstractMiddleware} or {EventHandler} is higher in the
      # stack and will report the exception and complete the transaction.
      #
      # @see #instrument_app_call_with_exception_handling
      def instrument_app_call(env, transaction)
        if @instrument_event_name
          Appsignal.instrument(
            @instrument_event_name,
            :opentelemetry_scope => @opentelemetry_scope
          ) do
            call_app(env, transaction)
          end
        else
          call_app(env, transaction)
        end
      end

      def call_app(env, transaction)
        status, headers, obody = @app.call(env)
        # Remember the status for {#add_opentelemetry_response_attributes}, which
        # runs once this event has closed.
        env[Appsignal::Rack::APPSIGNAL_RESPONSE_STATUS] = status
        body =
          if env[Appsignal::Rack::APPSIGNAL_RESPONSE_INSTRUMENTED]
            obody
          else
            env[Appsignal::Rack::APPSIGNAL_RESPONSE_INSTRUMENTED] = true
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
      # @see #instrument_app_call
      def instrument_app_call_with_exception_handling(env, transaction, wrapped_instrumentation)
        instrument_app_call(env, transaction)
      rescue Exception => error
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
        Appsignal::Rack::ApplyRackRequest
          .new(request, @options)
          .apply_to(transaction)
      end

      def request_for(env)
        @request_class.new(env)
      end
    end
  end
end
