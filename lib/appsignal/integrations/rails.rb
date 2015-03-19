if defined?(::Rails)
  Appsignal.logger.info("Loading Rails (#{Rails.version}) integration")

  module Appsignal
    module Integrations
      class Railtie < ::Rails::Railtie
        initializer 'appsignal.configure_rails_initialization' do |app|
          Appsignal::Integrations::Railtie.initialize_appsignal(app)
        end

        def self.initialize_appsignal(app)
          # Start logger
          Appsignal.start_logger(Rails.root.join('log'))

          # Load config
          Appsignal.config = Appsignal::Config.new(
            Rails.root,
            ENV.fetch('APPSIGNAL_APP_ENV', Rails.env),
            :name => Rails.application.class.parent_name
          )

          app.middleware.insert_before(
            ActionDispatch::RemoteIp,
            Appsignal::Rack::Listener
          )

          if Appsignal.config.active? &&
            Appsignal.config[:enable_frontend_error_catching] == true
            app.middleware.insert_before(
              Appsignal::Rack::Listener,
              Appsignal::Rack::JSExceptionCatcher,
            )
          end

          Appsignal.start
        end
      end
    end
  end
end
