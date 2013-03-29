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
          :time => event.time.to_f,
          :end => event.end.to_f,
          :payload => event.payload
        }
      end

      def basic_process_action_event
        super.merge(
          :environment => filtered_environment,
          :session_data => request.session
        )
      end

    end
  end
end
