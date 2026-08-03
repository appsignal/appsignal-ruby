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
          :opentelemetry_scope => ["appsignal-ruby/excon", Appsignal::VERSION]
        ) do
          # Describes the span as an outgoing HTTP request. Together with the
          # CLIENT kind, this is what the trace timeline reads to recognize it
          # as one. Excon reports the request and the response as two separate
          # notifications, and only the request one says where the request went,
          # so nothing is set for the response one.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpClientRequest.attributes_for(
              :method => data[:method],
              :scheme => data[:scheme],
              :host => data[:host],
              :port => data[:port],
              :path => data[:path]
            )
          )
          # Describes the response, which the semantic conventions ask for
          # whenever one was received. Only the response notification carries the
          # status, so this is the span it lands on, which is not the same span
          # the rest of the request's attributes are on.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpResponse.attributes_for(data[:status])
          )
          block&.call
        end
      end
    end
  end
end
