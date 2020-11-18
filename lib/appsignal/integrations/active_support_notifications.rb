# frozen_string_literal: true

module Appsignal
  module Integrations
    module ActiveSupportNotificationsIntegration
      BANG = "!".freeze

      def instrument(name, payload = {}, &block)
        # Events that start with a bang are internal to Rails
        instrument_this = name[0] != BANG

        Appsignal::Transaction.current.start_event if instrument_this

        super
      ensure
        if instrument_this
          title, body, body_format = Appsignal::EventFormatter.format(name, payload)
          Appsignal::Transaction.current.finish_event(
            name.to_s,
            title,
            body,
            body_format
          )
        end
      end
    end
  end
end
