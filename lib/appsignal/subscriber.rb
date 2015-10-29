module Appsignal
  class Subscriber
    BLANK = ''.freeze

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
      return if transaction.paused?

      Appsignal::Extension.start_event(transaction.transaction_index)
    end

    def finish(name, id, payload)
      return unless transaction = Appsignal::Transaction.current
      return if transaction.paused?

      if payload.include?(:appsignal_preformatted)
        title = payload[:title]
        body = payload[:body]
      else
        title, body = Appsignal::EventFormatter.format(name, payload)
      end
      Appsignal::Extension.finish_event(
        transaction.transaction_index,
        name,
        title || BLANK,
        body || BLANK
      )
    end
  end
end
