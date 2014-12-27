module Appsignal
  class Agent
    class Subscriber
      PROCESS_ACTION_PREFIX = 'process_action'.freeze
      PERFORM_JOB_PREFIX    = 'perform_job'.freeze
      BLANK                 = ''.freeze

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

      def make_digest(name, title, body)
        Digest::MD5.hexdigest("#{name}-#{title}-#{body}")
      end

      def publish(name, *args)
        # Not used
      end

      def start(name, id, payload)
        Appsignal::Native.start_event(id)
      end

      def finish(name, id, payload)
        title, body = Appsignal::EventFormatter.format(name, payload)
        Appsignal::Native.finish_event(
          id,
          name,
          title || BLANK,
          body || BLANK
        )

        if Appsignal::Transaction.current &&
           name.start_with?(PROCESS_ACTION_PREFIX, PERFORM_JOB_PREFIX)
          Appsignal::Transaction.current.set_root_event(name, payload)
        end
      end
    end
  end
end
