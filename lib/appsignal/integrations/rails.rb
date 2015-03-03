if defined?(::Rails)
  Appsignal.logger.info("Loading Rails (#{Rails.version}) integration")

  module Appsignal
    module Integrations
      class Railtie < ::Rails::Railtie
        initializer 'appsignal.configure_rails_initialization' do |app|
          app.middleware.insert_before(
            ActionDispatch::RemoteIp,
            Appsignal::Rack::JSExceptionCatcher
          )
          app.middleware.insert_after(
            Appsignal::Rack::JSExceptionCatcher,
            Appsignal::Rack::Listener
          )
        end

        config.after_initialize do
          # Start logger
          Appsignal.start_logger(Rails.root.join('log'))

          # Load config
          Appsignal.config = Appsignal::Config.new(
            Rails.root,
            Rails.env,
            :name => Rails.application.class.parent_name
          )

          Appsignal.start
        end
      end
    end
  end
end
