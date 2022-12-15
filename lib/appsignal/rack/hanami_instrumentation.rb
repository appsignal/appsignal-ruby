# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class HanamiInstrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug "Initializing Appsignal::Rack::HanamiInstrumentation"
        @app = app
        @options = options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        params = ::Hanami::Action::BaseParams.new(env)
        request = ::Hanami::Action::Request.new(
          :env => env,
          :params => params,
          :sessions_enabled => true
        )

        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )

        begin
          Appsignal.instrument("process_action.hanami") do
            @app.call(env)
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.params = request.params.to_h
          transaction.set_action_if_nil("#{request.request_method} #{request.path}")
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
