if defined?(::Rails)
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
          # Setup logging
          if File.writable?(Rails.root.join('log'))
            output = Rails.root.join('log/appsignal.log')
          else
            output = STDOUT
          end
          Appsignal.logger = Logger.new(output).tap do |l|
            l.level = Logger::INFO
          end
          Appsignal.flush_in_memory_log

          # Load config
          Appsignal.config = Appsignal::Config.new(Rails.root, Rails.env)

          # Start agent if config for this env is present
          Appsignal.start if Appsignal.active?
        end
      end
    end
  end
end
