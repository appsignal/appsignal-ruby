module Appsignal
  class Agent
    class Subscriber
      attr_reader :agent

      def initialize(agent)
        @agent = agent
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
        # Not used
      end

      def start(name, id, payload)
        return if !Appsignal::Transaction.current || agent.paused

        timestack = Thread.current[:appsignal_timestack] ||= []
        timestack.push([Time.now, 0.0])
      end

      def finish(name, id, payload)
        return if !Appsignal::Transaction.current || agent.paused

        timestack = Thread.current[:appsignal_timestack]
        started, child_duration = timestack.pop
        duration = Time.now - started
        timestack_length = timestack.length
        if timestack_length > 0
          timestack[timestack_length - 1][1] += duration
        end

        formatted = Appsignal::EventFormatter.format(name, payload)
        if formatted
          digest = Digest::MD5.hexdigest("#{name}-#{formatted[0]}-#{formatted[1]}")
          agent.add_event_details(digest, name, formatted[0], formatted[1])
        else
          digest = nil
        end

        Appsignal::Transaction.current.add_event(
          digest,
          name,
          started.to_f,
          duration,
          child_duration,
          timestack_length
        )
      end
    end
  end
end
