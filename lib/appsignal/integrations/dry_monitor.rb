# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module DryMonitorIntegration
      # ROM emits its SQL queries as dry-monitor `"sql"` events; tag those as
      # CLIENT in collector mode to match the dedicated DB integrations. Span
      # kind is immutable, so it has to be set here at event start.
      def instrument(event_id, payload = {}, &block)
        Appsignal::Transaction.current.start_event(
          :opentelemetry_kind => event_id.to_s == "sql" ? :client : nil,
          :opentelemetry_scope => ["appsignal-ruby-dry_monitor", Appsignal::VERSION]
        )

        super
      ensure
        title, body, body_format = Appsignal::EventFormatter.format("#{event_id}.dry", payload)

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
