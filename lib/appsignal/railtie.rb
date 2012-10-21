require 'appsignal'

module Appsignal
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'tasks/appsignal_tasks'
    end

    initializer "appsignal.configure_rails_initialization" do |app|
      app.middleware.insert_before ActionDispatch::RemoteIp,
        Appsignal::Middleware

      Appsignal.subscriber = ActiveSupport::Notifications.subscribe do |*args|
        if Appsignal::Transaction.current
          event = ActiveSupport::Notifications::Event.new(*args)
          if event.name == 'process_action.action_controller'
            Appsignal::Transaction.current.set_log_entry(event)
          else
            Appsignal::Transaction.current.add_event(event)
          end
        end
      end
    end
  end
end
