# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # Stub old middleware. Prevents Sinatra middleware being loaded twice.
    # This can happen when users use the old method of including
    # `use Appsignal::Rack::SinatraInstrumentation` in their modular Sinatra
    # applications. This is no longer needed. Instead Appsignal now includes
    # `use Appsignal::Rack::SinatraBaseInstrumentation` automatically.
    #
    # @api private
    class SinatraInstrumentation
      def initialize(app, options = {})
        @app = app
        @options = options
        Appsignal.internal_logger.warn "Please remove Appsignal::Rack::SinatraInstrumentation " \
          "from your Sinatra::Base class. This is no longer needed."
      end

      def call(env)
        @app.call(env)
      end

      def settings
        @app.settings
      end
    end

    class SinatraBaseInstrumentation < GenericInstrumentation
      def initialize(app, options = {})
        super
        @options[:request_class] ||= Sinatra::Request
        @instrument_span_name = "process_action.sinatra"
      end

      def set_transaction_attributes_from_request(transaction, request)
        # If raise_error is off versions of Sinatra don't raise errors, but store
        # them in the sinatra.error env var.
        if raise_errors_on? && env["sinatra.error"] && !env["sinatra.skip_appsignal_error"]
          transaction.set_error(env["sinatra.error"])
        end
        transaction.set_action_if_nil(action_name_from_sinatra_route(request.env))
        
        # If action is still nil, the call to super will set it to the default value
        super
      end

      def raise_errors_on?
        @app.respond_to?(:settings) &&
          @app.settings.respond_to?(:raise_errors) &&
          @app.settings.raise_errors
      end

      alias_method :raise_errors_on, :raise_errors_on?

      private

      def action_name_from_sinatra_route(env)
        return unless env["sinatra.route"]

        if env["SCRIPT_NAME"]
          method, route = env["sinatra.route"].split
          "#{method} #{env["SCRIPT_NAME"]}#{route}"
        else
          env["sinatra.route"]
        end
      end
    end
  end
end
