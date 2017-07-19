require "rack"

module Appsignal
  module Rack
    # Add this middleware to your app
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
        controller = hanami_action(env)
        request = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          Appsignal.instrument("process_action.generic") do
            @app.call(env)
          end
        rescue => error
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil(controller) if controller
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end

      def hanami_action(env)
        Web.routes.recognize(env).action.to_s
      end
    end
  end
end
