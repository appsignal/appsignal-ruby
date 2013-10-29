module Appsignal
  module Rack
    class Listener
      def initialize(app, options = {})
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
        Appsignal::Transaction.create(env['action_dispatch.request_id'], env)
        @app.call(env)
      rescue Exception => exception
        unless Appsignal.is_ignored_exception?(exception)
          Appsignal::Transaction.current.add_exception(exception)
        end
        raise exception
      ensure
        Appsignal::Transaction.current.complete!
      end
    end
  end
end
