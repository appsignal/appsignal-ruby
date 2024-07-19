# frozen_string_literal: true

module Appsignal
  module Loaders
    class HanamiLoader < Loader
      register :hanami

      def on_load
        hanami_app_config = ::Hanami.app.config
        register_config_defaults(
          :root_path => hanami_app_config.root.to_s,
          :env => hanami_app_config.env
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

        ::Hanami::Action.prepend Appsignal::Loaders::HanamiLoader::HanamiIntegration
      end

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
