# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # @api private
    class AbstractMiddleware
      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class}"
        @app = app
        @options = options
        @request_class = options.fetch(:request_class, ::Rack::Request)
        @params_method = options.fetch(:params_method, :params)
        @instrument_span_name = options.fetch(:instrument_span_name, "process.abstract")
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

          add_transaction_metadata_before(transaction, request)
          if wrapped_instrumentation
            instrument_wrapped_request(request, transaction)
          else
            # Set transaction on the request environment so other nested
            # middleware can detect if there is parent instrumentation
            # middleware active.
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
            instrument_request(request, transaction)
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
      # Either another {GenericInstrumentation} or {EventHandler} is higher in
      # the stack and will report the exception and complete the transaction.
      #
      # @see {#instrument_request}
      def instrument_wrapped_request(request, transaction)
        instrument_app_call(request.env)
      ensure
        add_transaction_metadata_after(transaction, request)
      end

      # Instrument the request fully. This is used by the top instrumentation
      # middleware in the middleware stack. Unlike
      # {#instrument_wrapped_request} this will report any exceptions being
      # raised.
      #
      # @see {#instrument_wrapped_request}
      def instrument_request(request, transaction)
        instrument_app_call(request.env)
      rescue Exception => error # rubocop:disable Lint/RescueException
        transaction.set_error(error)
        raise error
      ensure
        add_transaction_metadata_after(transaction, request)

        # Complete transaction because this is the top instrumentation middleware.
        Appsignal::Transaction.complete_current!
      end

      def instrument_app_call(env)
        Appsignal.instrument(@instrument_span_name) do
          @app.call(env)
        end
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
          request.env["appsignal.route"] || request.env["appsignal.action"]
        transaction.set_action_if_nil(default_action)
        transaction.set_metadata("path", request.path)
        transaction.set_metadata("method", request.request_method)
        transaction.set_params_if_nil(params_for(request))
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

      def request_for(env)
        @request_class.new(env)
      end
    end
  end
end
