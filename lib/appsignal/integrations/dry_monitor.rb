# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module DryMonitorIntegration
      # The event's formatter says what kind of work the event is, such as ROM
      # reporting a SQL query as a dry-monitor `"sql"` event. Span kind is
      # immutable, so it has to be set here at event start.
      def instrument(event_id, payload = {}, &block)
        name = "#{event_id}.dry"
        # An event a dedicated integration already records is not recorded a
        # second time here.
        return super unless Appsignal::EventFormatter.record?(name)

        begin
          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => Appsignal::EventFormatter.opentelemetry_kind(name),
            :opentelemetry_scope => ["appsignal-ruby/dry_monitor", Appsignal::VERSION]
          )

          super
        ensure
          title, body, body_format = Appsignal::EventFormatter.format(name, payload)

          Appsignal::Transaction.current.finish_event(
            title || event_id.to_s,
            title,
            body,
            body_format
          )
        end
      end
    end
  end
end
