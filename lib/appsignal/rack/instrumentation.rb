module Appsignal
  module Rack
    class Instrumentation
      def initialize(app, options = {})
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
        request = ::Rack::Request.new(env)
        {
          :action => "#{request.request_method}:#{request.path}",
          :params => request.params,
          :method => request.request_method,
          :path   => request.path
        }
      end
    end
  end
end
