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
        if Appsignal.active?
          Appsignal.start

          # Shutdown at exit. This does not work in passenger, see integrations/passenger
          at_exit { Appsignal.agent.shutdown(true) }

          # Subscribe to notifications that don't start with a !
          Appsignal.subscriber = ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
            if Appsignal::Transaction.current
              event = ActiveSupport::Notifications::Event.new(*args)
              if event.name == 'process_action.action_controller'
                Appsignal::Transaction.current.set_process_action_event(event)
              end
              Appsignal::Transaction.current.add_event(event)
            end
          end
        end
      end
    end
  end
end
