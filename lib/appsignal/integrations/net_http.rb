# frozen_string_literal: true

module Appsignal
  module Integrations
    module NetHttpIntegration
      def request(request, body = nil, &block)
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
