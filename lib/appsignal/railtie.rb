module Appsignal
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/auth_check.rake"
    end

    initializer "appsignal.configure_rails_initialization" do |app|
      # Some apps when run from the console do not have Rails.root set, there's
      # currently no way to spec this.
      if Rails.root
        Appsignal.logger = Logger.new(Rails.root.join('log/appsignal.log')).tap do |l|
          l.level = Logger::INFO
        end
        Appsignal.flush_in_memory_log
      end

      if Appsignal.active?
        Appsignal.logger.info("Activating appsignal-#{Appsignal::VERSION}")
        at_exit { Appsignal.agent.shutdown(true) }
        app.middleware.
          insert_before(ActionDispatch::RemoteIp, Appsignal::Listener)

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

require 'appsignal/to_appsignal_hash'
