# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module NetHttpIntegration
      def request(request, body = nil, &block)
        # Skip when an outer HTTP client integration (Faraday) already records
        # this request, so it isn't instrumented twice.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.http_client_events_suppressed?
          return super
        end

        Appsignal.instrument(
          "request.net_http",
          "#{request.method} #{use_ssl? ? "https" : "http"}://#{request["host"] || address}"
        ) do
          super
        end
      end
    end
  end
end
