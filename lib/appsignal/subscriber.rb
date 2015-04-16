module Appsignal
  class Subscriber
    PROCESS_ACTION_PREFIX = 'process_action'.freeze
    PERFORM_JOB_PREFIX    = 'perform_job'.freeze
    BLANK                 = ''.freeze

    def initialize
      subscribe
    end

    def subscribe
      Appsignal.logger.debug('Subscribing to notifications')
      # Subscribe to notifications that don't start with a !
      ActiveSupport::Notifications.subscribe(/^[^!]/, self)
    end

    def unsubscribe
      Appsignal.logger.debug('Unsubscribing from notifications')
      ActiveSupport::Notifications.unsubscribe(self)
    end

    def resubscribe
      Appsignal.logger.debug('Resubscribing to notifications')
      unsubscribe
      subscribe
    end

    def publish(name, *args)
      # Not used, it's part of AS notifications but is not used in Rails
      # and it seems to be unclear what it's function is. See:
      # https://github.com/rails/rails/blob/master/activesupport/lib/active_support/notifications/fanout.rb#L49
    end

    def start(name, id, payload)
      return unless transaction = Appsignal::Transaction.current

      Appsignal::Extension.start_event(transaction.request_id)
    end

    def finish(name, id, payload)
      return unless transaction = Appsignal::Transaction.current

      title, body = Appsignal::EventFormatter.format(name, payload)
      Appsignal::Extension.finish_event(
        transaction.request_id,
        name,
        title || BLANK,
        body || BLANK
      )

      if name.start_with?(PROCESS_ACTION_PREFIX, PERFORM_JOB_PREFIX)
        transaction.set_root_event(name, payload)
      end
    end
  end
end
