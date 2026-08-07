# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module DryMonitorIntegration
      def instrument(event_id, payload = {}, &block)
        Appsignal::Transaction.current.start_event

        super
      ensure
        name = "#{event_id}.dry"
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
