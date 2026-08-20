# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module DryMonitorIntegration
      # The event's formatter says what kind of work the event is, such as ROM
      # reporting a SQL query as a dry-monitor `"sql"` event, and which library
      # the instrumentation is for. Both are immutable once the span exists, so
      # they have to be set here at event start.
      #
      # dry-monitor is a notification bus, so an event arriving over it is not
      # necessarily dry-monitor's own work. A formatter that knows better says
      # so; anything else is attributed to dry-monitor.
      def instrument(event_id, payload = {}, &block)
        name = "#{event_id}.dry"
        # An event a dedicated integration already records is not recorded a
        # second time here.
        return super unless Appsignal::EventFormatter.record?(name)

        begin
          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => Appsignal::EventFormatter.opentelemetry_kind(name),
            :opentelemetry_scope =>
              Appsignal::EventFormatter.opentelemetry_scope(name) ||
                ["appsignal-ruby/dry_monitor", Appsignal::VERSION]
          )

          super
        ensure
          event_name, body, body_format = Appsignal::EventFormatter.format(name, payload)
          # Set while the event's span is still open, so the attributes land
          # on the event rather than on the transaction.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::EventFormatter.opentelemetry_attributes(name, payload)
          )

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
end
