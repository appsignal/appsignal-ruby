module Appsignal
  module Rack
    class Instrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::Instrumentation'
        @app, @options = app, options
      end

      def call(env)
        ActiveSupport::Notifications.instrument(
          'process_action.rack',
          raw_payload(env)
        ) do |payload|
          @app.call(env)
        end
      end

      def raw_payload(env)
        request = @options.fetch(:request_class, ::Rack::Request).new(env)
        params = request.public_send(@options.fetch(:params_method, :params))
        {
          :action => "#{request.request_method}:#{request.path}",
          :params => params,
          :method => request.request_method,
          :path   => request.path
        }
      end
    end
  end
end
