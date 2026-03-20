# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module HttpIntegration
      def self.instrument(verb, uri, &block)
        uri_module = defined?(HTTP::URI) ? HTTP::URI : URI
        parsed_request_uri = uri.is_a?(URI) ? uri : uri_module.parse(uri.to_s)
        request_uri = "#{parsed_request_uri.scheme}://#{parsed_request_uri.host}"

        Appsignal.instrument("request.http_rb", "#{verb.upcase} #{request_uri}", &block)
      end

      module HashOptions
        def request(verb, uri, opts = {})
          HttpIntegration.instrument(verb, uri) { super }
        end
      end

      module KeywordOptions
        def request(verb, uri, **opts)
          HttpIntegration.instrument(verb, uri) { super }
        end
      end
    end
  end
end
