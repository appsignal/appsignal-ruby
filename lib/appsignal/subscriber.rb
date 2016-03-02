module Appsignal
  class Subscriber
    BLANK = ''.freeze

    attr_reader :as_subscriber

    def initialize
      subscribe
    end

    def subscribe
      Appsignal.logger.debug('Subscribing to notifications')
      # Subscribe to notifications that don't start with a !
      @as_subscriber = ActiveSupport::Notifications.subscribe(/^[^!]/, self)
    end

    def unsubscribe
      if @as_subscriber
        Appsignal.logger.debug('Unsubscribing from notifications')
        ActiveSupport::Notifications.unsubscribe(@as_subscriber)
        @as_subscriber = nil
      end
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
      return if transaction.nil_transaction? || transaction.paused?

      Appsignal::Extension.start_event(transaction.transaction_index)
    end

    def finish(name, id, payload)
      return unless transaction = Appsignal::Transaction.current
      return if transaction.nil_transaction? || transaction.paused?

      title, body, body_format = Appsignal::EventFormatter.format(name, payload)
      Appsignal::Extension.finish_event(
        transaction.transaction_index,
        name,
        title || BLANK,
        body || BLANK,
        body_format || 0
      )
    end
  end
end
