# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe an outgoing HTTP request.
    #
    # The semantic conventions ask for the request method, the host and port
    # being called, and the full URL. Those together are also what the trace
    # timeline reads to recognize an outgoing request.
    #
    # The URL is built from the parts rather than taken whole, which has two
    # consequences worth knowing about.
    #
    # It never contains credentials. A URL can carry a username and password,
    # which the conventions say must not be sent. Building the URL from the
    # scheme, host, port and path means there is nowhere for them to come from.
    #
    # It never contains the query string either. The conventions do ask for it,
    # but the query string of a call to somebody else's API is the part most
    # likely to carry a key or a token, and unlike an incoming request it is not
    # something the application chose the shape of. Anything a caller passes as a
    # path is cut at the first question mark for the same reason, because some
    # clients hand us a request target rather than a path.
    module HttpClientRequest
      ADDRESS_ATTRIBUTE = "server.address"
      PORT_ATTRIBUTE = "server.port"
      URL_ATTRIBUTE = "url.full"

      # The port each scheme uses when a URL does not name one. Left out of the
      # URL, which is how a URL is normally written, but still reported as the
      # port, which the conventions ask for either way.
      DEFAULT_PORTS = {
        "http" => 80,
        "https" => 443
      }.freeze

      class << self
        # The attributes describing the given request, as a Hash to pass to
        # `add_opentelemetry_attributes`. Takes the request's parts, because
        # some clients hand us a URI and others only the parts.
        def attributes_for(method:, scheme: nil, host: nil, port: nil, path: nil)
          attributes = HttpMethod.attributes_for(method)
          attributes[ADDRESS_ATTRIBUTE] = host.to_s unless host.to_s.empty?

          port = port_for(scheme, port)
          attributes[PORT_ATTRIBUTE] = port if port

          url = url_for(scheme, host, port, path)
          attributes[URL_ATTRIBUTE] = url if url

          attributes
        end

        private

        # A client that was not given a port uses the one its scheme implies, so
        # report that rather than nothing.
        def port_for(scheme, port)
          Integer(port, :exception => false) || DEFAULT_PORTS[scheme.to_s]
        end

        def url_for(scheme, host, port, path)
          return if scheme.to_s.empty? || host.to_s.empty?

          url = +"#{scheme}://#{host}"
          url << ":#{port}" if port && port != DEFAULT_PORTS[scheme.to_s]
          url << path_without_query(path)
          url
        end

        # Some clients report the path of a request to the root of a host as
        # empty, and others as "/". The request goes to "/" either way, so say so
        # rather than let the URL differ by which client made the request.
        def path_without_query(path)
          without_query = path.to_s.split("?", 2).first.to_s
          without_query.empty? ? "/" : without_query
        end
      end
    end
  end
end
