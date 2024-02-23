# frozen_string_literal: true

require "rack"
require "delegate"

module Appsignal
  # @api private
  module Rack
    class GenericInstrumentation
      # This wrapper is necessary because the request may get initialized in an outer middleware, before
      # the ActionDispatch request gets created. In that case, the Rack request will take precedence
      # and the Rails filtered params are not going to be honored, potentially revealing user data.
      # This wrapper will check whether the actual Rack env contains an ActionDispatch request
      # and delegate the "filtered_params" call to it when the transaction gets completed. This will
      # ensure that if there was a Rails request somewhere in the handling flow upstream from this
      # middleware, its filtered params will end up used for the Appsignal transaction. So barring
      # a few edge cases even when GenericInstrumentation gets mounted from a Rails app' `config.ru`
      # there will still be no involuntary disclosure of data that is supposed to get filtered
      class FilteredParamsWrapper < SimpleDelegator
        def filtered_params
          actual_request = __getobj__
          if actual_request.respond_to?(:filtered_params)
            actual_request.filtered_params
          elsif has_rails_filtered_params?(actual_request)
            # This will delegate to the request itself in case of Rails
            actual_request.env["action_dispatch.request"].filtered_params
          else
            actual_request.params
          end
        end

        def has_rails_filtered_params?(req)
          # `env` is available on both ActionDispatch::Request and Rack::Request
          req.respond_to?(:env) && req.env["action_dispatch.request"] && req.env["action_dispatch.request"].respond_to?(:filtered_params)
        end
      end

      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class}"
        @app = app
        @options = options
        @instrument_span_name = "process_action.generic"
      end

      def call(env)
        if Appsignal.active? && !env["appsignal.transaction"]
          call_with_new_appsignal_transaction(env)
        elsif Appsignal.active?
          call_with_existing_appsignal_transaction(env)
        else
          call_without_appsignal_transaction(env)
        end
      end

      def call_without_appsignal_transaction(env)
        nil_transaction = Appsignal::Transaction::NilTransaction.new
        status, headers, obody = @app.call(env)
        [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, nil_transaction)]
      end

      def parse_or_reuse_request(env)
        request_class = @options.fetch(:request_class, ::Rack::Request)
        request_class.new(env)
      end

      def create_transaction_from_request(request)
        # A middleware may support more options besides the ones supported by the Transaction
        default_options = {:force => false, :params_method => :filtered_params}
        options_for_transaction = default_options.merge!(@options.slice(:force, :params_method))

        Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          FilteredParamsWrapper.new(request),
          options_for_transaction
        )
      end


      def call_with_existing_appsignal_transaction(env)
        request = parse_or_reuse_request(env)
        transaction = env["appsignal.transaction"]
        Appsignal.instrument(@instrument_span_name) { @app.call(env) }
        # Rescuing the exception from `call` will be handled by the middleware which
        # added the transaction to the Rack env
      ensure
        set_transaction_attributes_from_request(transaction, request)
      end

      def call_with_new_appsignal_transaction(env)
        request = parse_or_reuse_request(env)
        transaction = create_transaction_from_request(request)
        env["appsignal.transaction"] = transaction

        # We need to complete the transaction if there is an exception inside the `call`
        # of the app. If there isn't one and the app returns us a Rack response triplet, we let
        # the BodyWrapper complete the transaction when #close gets called on it
        # (guaranteed by the webserver)
        complete_transaction_without_body = false
        begin
          Appsignal.instrument(@instrument_span_name) do
            status, headers, obody = @app.call(env)
            [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, transaction)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          complete_transaction_without_body = true
          raise error
        ensure
          set_transaction_attributes_from_request(transaction, request)
          # Transaction gets completed when the body gets read out, except in cases when
          # the app failed before returning us the Rack response triplet.
          Appsignal::Transaction.complete_current! if complete_transaction_without_body
        end
      end

      def set_transaction_attributes_from_request(transaction, request)
        default_action = request.env["appsignal.route"] || request.env["appsignal.action"] || "unknown"
        transaction.set_action_if_nil(action_name_for_transaction)
        transaction.set_metadata("path", request.path)
        transaction.set_metadata("method", request.request_method)
        transaction.set_http_or_background_queue_start
      end
    end
  end
end
