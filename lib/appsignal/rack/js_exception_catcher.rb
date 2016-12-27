module Appsignal
  module Rack
    class JSExceptionCatcher
      def initialize(app, options = {})
        Appsignal.logger.debug "Initializing Appsignal::Rack::JSExceptionCatcher"
        @app = app
        @options = options
      end

      def call(env)
        if env["PATH_INFO"] == Appsignal.config[:frontend_error_catching_path]
          body = JSON.parse(env["rack.input"].read)

          if body["name"].is_a?(String) && !body["name"].empty?
            transaction = JSExceptionTransaction.new(body)
            transaction.complete!
            code = 200
          else
            Appsignal.logger.debug "JSExceptionCatcher: Could not send exception, 'name' is empty."
            code = 422
          end

          [code, {}, []]
        else
          @app.call(env)
        end
      end
    end
  end
end
