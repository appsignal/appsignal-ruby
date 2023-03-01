# frozen_string_literal: true

module Appsignal
  module Integrations
    module DryMonitorIntegration
      def instrument(event_id, payload = {}, &block)
        Appsignal::Transaction.current.start_event

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
