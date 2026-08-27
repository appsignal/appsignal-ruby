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
    # they build. They do build it in one method, `http_connection`, which
    # this module overrides to configure the connection it returns.
    #
    # This module is included into a subclass rather than prepended onto the
    # exporter itself, so that an application using the OpenTelemetry gems for
    # its own exporting is unaffected.
    #
    # That method is not part of the exporters' public API, so a later version
    # can rename it, stop calling it, or return something other than a
    # `Net::HTTP` from it. This module does not try to predict which of those
    # happened by inspecting the method. It records whether it managed to
    # configure a connection, and {#initialize} reports it when it did not, so
    # a version we cannot proxy through is visible in the log rather than
    # silently sending around the proxy.
    module ProxiedExporter
      def initialize(appsignal_http_proxy:, **kwargs)
        @appsignal_http_proxy = appsignal_http_proxy
        @appsignal_proxy_applied = false

        # The exporters build their connection while they initialize, so by
        # the time this returns the override below has either run or never
        # will.
        super(**kwargs)

        return if @appsignal_proxy_applied

        Appsignal.internal_logger.error(
          "Not sending #{self.class.superclass} data through the proxy in " \
            "the `http_proxy` option: this version of the OpenTelemetry " \
            "exporters does not build its connection where AppSignal " \
            "configures the proxy."
        )
      end

      # Whether the proxy was applied to the connection this exporter sends
      # through. False means the exporter sends straight to its endpoint.
      def appsignal_proxy_applied?
        @appsignal_proxy_applied
      end

      private

      # Accepts and forwards whatever the exporter calls this with, because
      # none of the arguments are read here. A version that adds an argument,
      # positional or keyword, is passed straight through instead of raising
      # on the way to `super`.
      def http_connection(*args, **kwargs)
        apply_appsignal_proxy(super)
      end

      # Point a connection at the proxy. Returns the connection either way, so
      # an exporter whose connection cannot be proxied still sends its data.
      def apply_appsignal_proxy(http)
        return http unless http.respond_to?(:proxy_from_env=)

        proxy = URI.parse(@appsignal_http_proxy)

        # `Net::HTTP#proxy?` reads the address only when the connection is not
        # taking its proxy from the environment, which it does by default.
        http.proxy_from_env = false
        http.proxy_address = proxy.host
        http.proxy_port = proxy.port
        http.proxy_user = proxy.user
        http.proxy_pass = proxy.password

        @appsignal_proxy_applied = true
        http
      end
    end
  end
end
