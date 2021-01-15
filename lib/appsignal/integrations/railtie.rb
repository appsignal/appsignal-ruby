# frozen_string_literal: true

Appsignal.logger.info("Loading Rails (#{Rails.version}) integration")

require "appsignal/utils/rails_helper"
require "appsignal/rack/rails_instrumentation"

module Appsignal
  module Integrations
    # @api private
    class Railtie < ::Rails::Railtie
      initializer "appsignal.configure_rails_initialization" do |app|
        Appsignal::Integrations::Railtie.initialize_appsignal(app)
      end

      def self.initialize_appsignal(app)
        # Load config
        Appsignal.config = Appsignal::Config.new(
          Rails.root,
          Rails.env,
          :name => Appsignal::Utils::RailsHelper.detected_rails_app_name,
          :log_path => Rails.root.join("log")
        )

        # Start logger
        Appsignal.start_logger

        app.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          Appsignal::Rack::RailsInstrumentation
        )

        if Appsignal.config[:enable_frontend_error_catching]
          app.middleware.insert_before(Appsignal::Rack::RailsInstrumentation)
        end

        Appsignal.start
      end
    end
  end
end
