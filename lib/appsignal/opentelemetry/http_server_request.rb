# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe an incoming HTTP
    # request.
    #
    # The semantic conventions ask for the request method, the path and the
    # scheme on the span of a request a server handled. Those three together are
    # also what the trace timeline reads to recognize a web request.
    #
    # The path is the concrete path the request was made to, such as `/users/1`.
    # It is not the route template the application matched it against, which the
    # conventions call `http.route` and which a Rack application does not
    # necessarily have.
    #
    # The query string is asked for whenever the request had one. It is sent
    # whole, without the leading question mark, and it is not filtered here. The
    # collector filters it with the `filter_request_query_parameters` option, and
    # builds the request's query parameters out of it.
    #
    # The host and the port describe where the client addressed the request. The
    # conventions ask for the host the client used, so a caller reads it through
    # the `Forwarded` and `X-Forwarded-Host` headers before falling back to the
    # `Host` header and then to the server's own name. That is the order
    # `Rack::Request#hostname` already follows. The port is only reported
    # alongside a host, which is the condition the conventions put on it.
    #
    # The protocol version is the version out of `HTTP/1.1`, without the name.
    #
    # Every value is optional, because reading any of them from the request can
    # fail. An attribute we have no value for is left out rather than sent
    # empty.
    module HttpServerRequest
      PATH_ATTRIBUTE = "url.path"
      SCHEME_ATTRIBUTE = "url.scheme"
      QUERY_ATTRIBUTE = "url.query"
      ADDRESS_ATTRIBUTE = "server.address"
      PORT_ATTRIBUTE = "server.port"
      PROTOCOL_VERSION_ATTRIBUTE = "network.protocol.version"

      class << self
        # The attributes describing the given request, as a Hash to pass to
        # `add_opentelemetry_attributes`.
        def attributes_for( # rubocop:disable Metrics/ParameterLists
          method:, path: nil, scheme: nil, query: nil, host: nil, port: nil, protocol: nil
        )
          attributes = HttpMethod.attributes_for(method)
          attributes[PATH_ATTRIBUTE] = path.to_s unless path.to_s.empty?
          attributes[SCHEME_ATTRIBUTE] = scheme.to_s unless scheme.to_s.empty?
          attributes[QUERY_ATTRIBUTE] = query.to_s unless query.to_s.empty?

          unless host.to_s.empty?
            attributes[ADDRESS_ATTRIBUTE] = host.to_s
            port = Integer(port, :exception => false)
            attributes[PORT_ATTRIBUTE] = port if port
          end

          version = protocol_version_for(protocol)
          attributes[PROTOCOL_VERSION_ATTRIBUTE] = version if version

          attributes
        end

        private

        # `network.protocol.name` is asked for alongside the version only when
        # the protocol is not HTTP. A value shaped any other way than `HTTP/x`
        # is one we cannot name, so it is left out entirely rather than sent as
        # a version with no name to go with it.
        def protocol_version_for(protocol)
          protocol.to_s[%r{\AHTTP/(.+)\z}, 1]
        end
      end
    end
  end
end
