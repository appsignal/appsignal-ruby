# frozen_string_literal: true

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

    class SinatraBaseInstrumentation < AbstractMiddleware
      attr_reader :raise_errors_on

      def initialize(app, options = {})
        options[:request_class] ||= Sinatra::Request
        options[:params_method] ||= :params
        options[:instrument_event_name] ||= "process_action.sinatra"
        super
        @raise_errors_on = raise_errors?(app)
      end

      private

      def add_transaction_metadata_after(transaction, request)
        env = request.env
        transaction.set_action_if_nil(action_name(env))
        # If raise_error is off versions of Sinatra don't raise errors, but store
        # them in the sinatra.error env var.
        if !raise_errors_on && env["sinatra.error"] && !env["sinatra.skip_appsignal_error"]
          transaction.set_error(env["sinatra.error"])
        end

        super
      end

      def action_name(env)
        return unless env["sinatra.route"]

        if env["SCRIPT_NAME"]
          method, route = env["sinatra.route"].split
          "#{method} #{env["SCRIPT_NAME"]}#{route}"
        else
          env["sinatra.route"]
        end
      end

      def raise_errors?(app)
        app.respond_to?(:settings) &&
          app.settings.respond_to?(:raise_errors) &&
          app.settings.raise_errors
      end
    end
  end
end
