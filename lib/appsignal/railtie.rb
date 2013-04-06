module Appsignal
  class Railtie < Rails::Railtie
    initializer "appsignal.configure_rails_initialization" do |app|
      Appsignal.logger = Logger.new(Rails.root.join('log/appsignal.log')).tap do |l|
        l.level = Logger::INFO
      end
      Appsignal.flush_in_memory_log

      if Appsignal.active?
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
