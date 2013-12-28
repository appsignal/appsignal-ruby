if defined?(::Rails)
  Appsignal.logger.info('Loading Rails integration')

  module Appsignal
    module Integrations
      class Railtie < ::Rails::Railtie
        initializer 'appsignal.configure_rails_initialization' do |app|
          app.middleware.insert_before(
            ActionDispatch::RemoteIp,
            Appsignal::Rack::Listener
          )
        end

        config.after_initialize do
          # Start logger
          Appsignal.start_logger(Rails.root.join('log'))

          # Load config
          Appsignal.config = Appsignal::Config.new(Rails.root, Rails.env)

          # Start agent if config for this env is present
          Appsignal.start if Appsignal.active?
        end
      end
    end
  end
end
