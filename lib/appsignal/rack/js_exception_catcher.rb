# frozen_string_literal: true

module Appsignal
  # @api private
  module Rack
    # JavaScript error catching middleware.
    #
    # Listens to the endpoint specified in the `frontend_error_catching_path`
    # configuration option.
    #
    # This is automatically included middleware in Rails apps if the
    # `frontend_error_catching_path` configuration option is active.
    #
    # If AppSignal is not active in the current environment, but does have
    # JavaScript error catching turned on, we assume that a JavaScript script
    # still sends errors to this endpoint. When AppSignal is not active in this
    # scenario this middleware still listens to the endpoint, but won't record
    # the error. It will return HTTP status code 202.
    #
    # @example with a Sinatra app
    #   Sinatra::Application.use(Appsignal::Rack::JSExceptionCatcher)
    #
    # @see http://docs.appsignal.com/front-end/error-handling.html
    # @api private
    class JSExceptionCatcher
      include Appsignal::Utils::DeprecationMessage

      def initialize(app, _options = nil)
        Appsignal.logger.debug \
          "Initializing Appsignal::Rack::JSExceptionCatcher"
        deprecation_message "The Appsignal::Rack::JSExceptionCatcher is " \
          "deprecated and will be removed in a future version. Please use " \
          "the official AppSignal JavaScript integration by disabling " \
          "`enable_frontend_error_catching` in your configuration and " \
          "installing AppSignal for Javascript instead. " \
          "(https://docs.appsignal.com/front-end/)"
        @app = app
      end

      def call(env)
        # Ignore other paths than the error catching path.
        return @app.call(env) unless error_cathing_endpoint?(env)

        # Prevent raising a 404 not found when a non-active environment posts
        # to this endpoint.
        unless Appsignal.active?
          return [
            202,
            {},
            ["AppSignal JavaScript error catching endpoint is not active."]
          ]
        end

        begin
          body = JSON.parse(env["rack.input"].read)
        rescue JSON::ParserError
          return [400, {}, ["Request payload is not valid JSON."]]
        end

        if body["name"].is_a?(String) && !body["name"].empty?
          transaction = JSExceptionTransaction.new(body)
          transaction.complete!
          code = 200
        else
          Appsignal.logger.debug \
            "JSExceptionCatcher: Could not send exception, 'name' is empty."
          code = 422
        end

        [code, {}, []]
      end

      private

      def error_cathing_endpoint?(env)
        env["PATH_INFO"] == Appsignal.config[:frontend_error_catching_path]
      end
    end
  end
end
