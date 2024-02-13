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

    class SinatraBaseInstrumentation
      attr_reader :raise_errors_on

      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing Appsignal::Rack::SinatraBaseInstrumentation"
        @app = app
        @options = options
        @raise_errors_on = raise_errors?(@app)
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          status, headers, obody = @app.call(env)
          [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, _transaction = nil)]
        end
      end

      def call_with_appsignal_monitoring(env)
        options = { :force => @options.include?(:force) && @options[:force] }
        options.merge!(:params_method => @options[:params_method]) if @options[:params_method]
        request = @options.fetch(:request_class, Sinatra::Request).new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          options
        )
        body_read_will_complete = false
        begin
          Appsignal.instrument("process_action.sinatra") do
            status, headers, obody = @app.call(env)
            body_read_will_complete = true
            [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, _transaction = nil)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          # If raise_error is off versions of Sinatra don't raise errors, but store
          # them in the sinatra.error env var.
          if !raise_errors_on && env["sinatra.error"] && !env["sinatra.skip_appsignal_error"]
            transaction.set_error(env["sinatra.error"])
          end
          transaction.set_action_if_nil(action_name(env))
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
          transaction.set_http_or_background_queue_start
          # Transaction gets completed when the body gets read out, except in cases when
          # the app failed before returning us the Rack response triplet.
          Appsignal::Transaction.complete_current! unless body_read_will_complete
        end
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

      private

      def raise_errors?(app)
        app.respond_to?(:settings) &&
          app.settings.respond_to?(:raise_errors) &&
          app.settings.raise_errors
      end
    end
  end
end
