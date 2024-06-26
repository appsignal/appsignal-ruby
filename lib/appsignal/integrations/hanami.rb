# frozen_string_literal: true

require "appsignal"
require "appsignal/rack/hanami_middleware"

module Appsignal
  module Integrations
    # @api private
    module HanamiPlugin
      def self.init
        Appsignal.internal_logger.debug("Loading Hanami integration")

        hanami_app_config = ::Hanami.app.config
        Appsignal.config = Appsignal::Config.new(
          hanami_app_config.root || Dir.pwd,
          hanami_app_config.env
        )

        Appsignal.start

        return unless Appsignal.active?

        hanami_app_config.middleware.use(
          ::Rack::Events,
          [Appsignal::Rack::EventHandler.new]
        )
        hanami_app_config.middleware.use(Appsignal::Rack::HanamiMiddleware)

        ::Hanami::Action.prepend Appsignal::Integrations::HanamiIntegration
      end
    end

    # @api private
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

Appsignal::Integrations::HanamiPlugin.init
