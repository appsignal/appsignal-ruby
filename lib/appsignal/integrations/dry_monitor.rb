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

        Appsignal::Transaction.current.start_event(
          :opentelemetry_kind => Appsignal::EventFormatter.opentelemetry_kind(name),
          :opentelemetry_scope => ["appsignal-ruby/dry_monitor", Appsignal::VERSION]
        )

        super
      ensure
        event_name, body, body_format = Appsignal::EventFormatter.format(name, payload)

        # dry-monitor reports an event under an id, such as `sql`, rather than
        # a name. A formatter names the event it knows about, and an event
        # without one is named after its id in the dry-monitor group. Either
        # way the name has a group, which is what an event is listed under.
        Appsignal::Transaction.current.finish_event(
          event_name || name,
          nil,
          body,
          body_format
        )
      end
    end
  end
end
