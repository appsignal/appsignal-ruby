module Appsignal
  module Rack
    class SinatraInstrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::SinatraInstrumentation'
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
        ActiveSupport::Notifications.instrument(
          'process_action.sinatra',
          raw_payload(env)
        ) do |payload|
          begin
            @app.call(env)
          ensure
            # This information is available only after the
            # request has been processed by Sinatra.
            payload[:action] = env['sinatra.route']
          end
        end
      ensure
        # In production newer versions of Sinatra don't raise errors, but store
        # them in the sinatra.error env var.
        Appsignal::Transaction.current.add_exception(env['sinatra.error']) if env['sinatra.error']
      end

      def raw_payload(env)
        request = @options.fetch(:request_class, ::Sinatra::Request).new(env)
        params = request.public_send(@options.fetch(:params_method, :params))
        {
          :params  => params,
          :session => request.session,
          :method  => request.request_method,
          :path    => request.path
        }
      end
    end
  end
end
