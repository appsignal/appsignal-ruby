require 'rack'

module Appsignal
  module Rack
    # Stub old middleware. Prevents Sinatra middleware being loaded twice.
    # This can happen when users use the old method of including
    # `use Appsignal::Rack::SinatraInstrumentation` in their modular Sinatra
    # applications. This is no longer needed. Instead Appsignal now includes
    # `use Appsignal::Rack::SinatraBaseInstrumentation` automatically.
    class SinatraInstrumentation
      def initialize(app, options = {})
        @app, @options = app, options
        Appsignal.logger.warn 'Please remove Appsignal::Rack::SinatraInstrumentation '\
          'from your Sinatra::Base class. This is no longer needed.'
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
        Appsignal.logger.debug 'Initializing Appsignal::Rack::SinatraInstrumentation'
        @app, @options = app, options
        @raise_errors_on = @app.settings.raise_errors
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        if @options[:params_method]
          env[:params_method] = @options[:params_method]
        end
        request = @options.fetch(:request_class, Sinatra::Request).new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          {:force => @options.include?(:force) && @options[:force]}
        )
        begin
          ActiveSupport::Notifications.instrument('process_action.sinatra') do
            @app.call(env)
          end
        rescue => error
          transaction.set_error(error)
          raise error
        ensure
          # If raise_error is off versions of Sinatra don't raise errors, but store
          # them in the sinatra.error env var.
          if !@raise_errors_on && env['sinatra.error'] && !env['sinatra.skip_appsignal_error']
            transaction.set_error(env['sinatra.error'])
          end
          transaction.set_action(action_name(env))
          transaction.set_metadata('path', request.path)
          transaction.set_metadata('method', request.request_method)
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end

      def action_name(env)
        return unless env['sinatra.route']

        if @options.fetch(:mounted_at, nil)
          method, route = env['sinatra.route'].split(" ")
          "#{method} #{@options[:mounted_at]}#{route}"
        elsif env['SCRIPT_NAME']
          method, route = env['sinatra.route'].split(" ")
          "#{method} #{env['SCRIPT_NAME']}#{route}"
        else
          env['sinatra.route']
        end
      end
    end
  end
end
