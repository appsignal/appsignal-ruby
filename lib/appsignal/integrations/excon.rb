# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ExconIntegration
      def self.instrument(name, data, &block)
        # Skip when an outer HTTP client integration (Faraday) already records
        # this request, so it isn't instrumented twice. Excon calls the
        # instrumentor for block-less notifications too, hence the `block_given?`.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.http_client_events_suppressed?
          return block_given? ? yield : nil
        end

        namespace, *event = name.split(".")
        rails_name = [event, namespace].flatten.join(".")

        title =
          if rails_name == "response.excon"
            data[:host]
          else
            "#{data[:method].to_s.upcase} #{data[:scheme]}://#{data[:host]}"
          end
        Appsignal.instrument(
          rails_name,
          title,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby-excon", Appsignal::VERSION],
          &block
        )
      end
    end
  end
end
