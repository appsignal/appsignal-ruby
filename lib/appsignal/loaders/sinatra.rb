# frozen_string_literal: true

module Appsignal
  module Loaders
    class SinatraLoader < Loader
      register :sinatra

      def on_load
        app_settings = ::Sinatra::Application.settings
        register_config_defaults(
          :root_path => app_settings.root,
          :env => app_settings.environment
        )
      end

      def on_start
        require "appsignal/rack/sinatra_instrumentation"

        ::Sinatra::Base.use(::Rack::Events, [Appsignal::Rack::EventHandler.new])
        ::Sinatra::Base.use(Appsignal::Rack::SinatraBaseInstrumentation)
      end
    end
  end
end
