module Appsignal
  module Grape
    class Middleware < ::Grape::Middleware::Base
      def initialize(app)
        @app = app
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        request      = ::Rack::Request.new(env)
        transaction  = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          @app.call(env)
        rescue => error
          transaction.set_error(error)
          raise error
        ensure
          api_endpoint = env['api.endpoint']
          if api_endpoint && options = api_endpoint.options
            method = options[:method].first
            klass  = options[:for]
            action = options[:path].first
            transaction.set_action("#{method}::#{klass}##{action}")
          end
          transaction.set_http_or_background_queue_start
          transaction.set_metadata('path', request.path)
          transaction.set_metadata('method', env['REQUEST_METHOD'])
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
