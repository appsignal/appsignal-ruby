require 'rack'

module Appsignal
  module Rack
    class GenericInstrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::GenericInstrumentation'
        @app, @options = app, options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        request = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          ActiveSupport::Notifications.instrument('process_action.generic') do
            @app.call(env)
          end
        rescue => error
          transaction.set_error(error)
          raise error
        ensure
          if env['appsignal.route']
            transaction.set_action(env['appsignal.route'])
          else
            transaction.set_action('unknown')
          end
          transaction.set_metadata('path', request.path)
          transaction.set_metadata('method', request.request_method)
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
