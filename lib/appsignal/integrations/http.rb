# frozen_string_literal: true

module Appsignal
  module Integrations
    module HttpIntegration
      def request(verb, uri, opts = {})
        parsed_request_uri = uri.is_a?(URI) ? uri : URI.parse(uri.to_s)
        request_uri = "#{parsed_request_uri.scheme}://#{parsed_request_uri.host}"

        begin
          Appsignal.instrument("request.http_rb", "#{verb.upcase} #{request_uri}") do
            super
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          Appsignal.set_error(error)
          raise error
        end
      end
    end
  end
end
