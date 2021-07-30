# frozen_string_literal: true

module Appsignal
  module Integrations
    module NetHttpIntegration
      def request(request, body = nil, &block)
        Appsignal.instrument(
          "request.net_http",
          "#{request.method} #{use_ssl? ? "https" : "http"}://#{request["host"] || address}"
        ) do
          super.tap do |response|
            if response[Appsignal::FINGERPRINT_HEADER_LOWERCASE]
              Appsignal::Transaction.current.add_fingerprint(response[Appsignal::FINGERPRINT_HEADER_LOWERCASE])
            end
          end
        end
      end
    end
  end
end
