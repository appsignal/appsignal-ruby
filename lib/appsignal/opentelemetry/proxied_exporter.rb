# frozen_string_literal: true

require "uri"

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Routes an OTLP exporter's requests through the proxy in the
    # `http_proxy` config option.
    #
    # The exporters accept no proxy and expose no way to reach the connection
    # they build. They do build it in one private method, `http_connection`,
    # which this module overrides to configure the connection it returns.
    #
    # This module is included into a subclass rather than prepended onto the
    # exporter itself, so that an application using the OpenTelemetry gems for
    # its own exporting is unaffected.
    module ProxiedExporter
      def initialize(appsignal_http_proxy:, **kwargs)
        @appsignal_http_proxy = appsignal_http_proxy
        super(**kwargs)
      end

      private

      def http_connection(*args)
        http = super
        proxy = URI.parse(@appsignal_http_proxy)

        # `Net::HTTP#proxy?` reads the address only when the connection is not
        # taking its proxy from the environment, which it does by default.
        http.proxy_from_env = false
        http.proxy_address = proxy.host
        http.proxy_port = proxy.port
        http.proxy_user = proxy.user
        http.proxy_pass = proxy.password

        http
      end
    end
  end
end
