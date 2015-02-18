module Appsignal
  module Rack
    class JSExceptionCatcher
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::JSExceptionCatcher'
        @app, @options = app, options
      end

      def call(env)
        if env['PATH_INFO'] == '/appsignal_error_catcher'
          if Appsignal.config.active?
            body        = JSON.parse(env['rack.input'].read)
            transaction = JSExceptionTransaction.new(body)
            transaction.complete!
          end
          return [ 200, {}, []]
        else
          @app.call(env)
        end
      end
    end
  end
end
