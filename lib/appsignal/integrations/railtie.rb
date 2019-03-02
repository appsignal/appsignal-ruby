# frozen_string_literal: true

Appsignal.logger.info("Loading Rails (#{Rails.version}) integration")

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
          :name => detected_rails_app_name,
          :log_path => Rails.root.join("log")
        )

        # Start logger
        Appsignal.start_logger

        app.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          Appsignal::Rack::RailsInstrumentation
        )

        if Appsignal.config[:enable_frontend_error_catching]
          app.middleware.insert_before(
            Appsignal::Rack::RailsInstrumentation,
            Appsignal::Rack::JSExceptionCatcher
          )
        end

        Appsignal.start
      end

      def self.detected_rails_app_name
        rails_class = Rails.application.class
        if rails_class.respond_to? :module_parent_name # Rails 6
          rails_class.module_parent_name
        else # Older Rails versions
          rails_class.parent_name
        end
      end
    end
  end
end
