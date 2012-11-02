module Appsignal
  class TransactionFormatter
    class SlowRequestFormatter < Appsignal::TransactionFormatter

      def to_hash
        super.merge :events => detailed_events
      end

      protected

      def detailed_events
        events.map { |event| format(event) }
      end

      def format(event)
        {
          :name => event.name,
          :duration => event.duration,
          :time => event.time,
          :end => event.end,
          :payload => sanitized_event_payload(event)
        }
      end

    end
  end
end
