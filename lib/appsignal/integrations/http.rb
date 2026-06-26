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

      # The event is recorded at the request boundary, so a redirected request
      # stays a single `request.http_rb` event spanning every hop. That boundary
      # lives in more than one place: a bare request runs through
      # `HTTP::Client#request`, but in http6 a chained request (`.follow`,
      # `.headers`, `.timeout`, ...) runs through `HTTP::Session#request`
      # instead, which never touches `Client#request`. The hook prepends one of
      # these onto each. `Client#request` takes positional options in http5 and
      # keyword options in http6; `Session#request` (http6 only) takes keyword
      # options.
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
