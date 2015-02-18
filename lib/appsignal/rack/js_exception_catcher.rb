module Appsignal
  module Rack
    class JSExceptionCatcher
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::JSExceptionCatcher'
        @app, @options = app, options
      end

      def call(env)
        if env['PATH_INFO'] == Appsignal.config[:frontend_error_catching_path]
          if Appsignal.config.active? &&
             Appsignal.config[:enable_frontend_error_catching] == true

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
