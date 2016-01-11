module Appsignal
  module UpdateActiveSupport
    def self.run
      # Get the old subscribers if present
      old_notifier = ActiveSupport::Notifications.notifier
      subscribers  = old_notifier.instance_variable_get('@subscribers') || []

      # Require the newer notifications
      require 'vendor/active_support/notifications'

      # Re-subscribe the old subscribers
      subscribers.each do |sub|
        pattern  = sub.instance_variable_get('@pattern')
        delegate = sub.instance_variable_get('@delegate')
        next unless pattern && delegate
        ActiveSupport::Notifications.subscribe(pattern, delegate)
      end
    end
  end
end
