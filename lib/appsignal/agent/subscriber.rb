module Appsignal
  class Agent
    class Subscriber
      PROCESS_ACTION_PREFIX = 'process_action'.freeze
      PERFORM_JOB_PREFIX    = 'perform_job'.freeze

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
        Zlib::crc32("#{name}-#{title}-#{body}")
      end

      def publish(name, *args)
        # Not used
      end

      def start(name, id, payload)
        return if agent.paused
        transaction = Appsignal::Transaction.current
        return if !transaction

        transaction.timestack.push([Time.now.to_f, 0.0])
      end

      def finish(name, id, payload)
        return if agent.paused
        transaction = Appsignal::Transaction.current
        return if !transaction

        started, child_duration = transaction.timestack.pop
        now = Time.now.to_f
        duration = now - started
        timestack_length = transaction.timestack.length
        if timestack_length > 0
          transaction.timestack[timestack_length - 1][1] += duration
        end

        if timestack_length == 0 && name.start_with?(PROCESS_ACTION_PREFIX, PERFORM_JOB_PREFIX)
          transaction.set_root_event(name, payload)
          digest = nil
        else
          formatted = Appsignal::EventFormatter.format(name, payload)
          if formatted
            digest = make_digest(name, formatted[0], formatted[1])
            agent.add_event_details(digest, name, formatted[0], formatted[1])
          else
            digest = nil
          end
        end

        agent.add_measurement(digest, name, now.to_i, :c => 1, :d => duration - child_duration)
        transaction.add_event(
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
