# frozen_string_literal: true

module Appsignal
  module Loaders
    class HanamiLoader < Loader
      register :hanami

      def on_load
        hanami_app_config = ::Hanami.app.config
        register_config_defaults(
          :root_path => hanami_app_config.root.to_s,
          :env => hanami_app_config.env,
          :ignore_errors => [
            "Hanami::Router::NotAllowedError",
            "Hanami::Router::NotFoundError"
          ]
        )
      end

      def on_start
        require "appsignal/rack/hanami_middleware"

        hanami_app_config = ::Hanami.app.config
        hanami_app_config.middleware.use(
          ::Rack::Events,
          [Appsignal::Rack::EventHandler.new]
        )
        hanami_app_config.middleware.use(Appsignal::Rack::HanamiMiddleware)

        return unless Gem::Version.new(Hanami::VERSION) < Gem::Version.new("2.2.0")

        ::Hanami::Action.prepend Appsignal::Loaders::HanamiLoader::HanamiIntegration
      end

      # Legacy instrumentation to set the action name in Hanami apps older than Hanami 2.2
      module HanamiIntegration
        def call(env)
          super
        ensure
          transaction = env[::Appsignal::Rack::APPSIGNAL_TRANSACTION]

          transaction&.set_action_if_nil(self.class.name)
        end
      end
    end
  end
end
