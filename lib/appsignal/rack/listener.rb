module Appsignal
  module Rack
    class Listener
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::Listener'
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
        Appsignal::Transaction.create(request_id(env), env)
        @app.call(env)
      rescue Exception => exception
        Appsignal.set_exception(exception)
        raise exception
      ensure
        Appsignal::Transaction.complete_current!
      end

      def request_id(env)
        env['action_dispatch.request_id'] || SecureRandom.uuid
      end
    end
  end
end
