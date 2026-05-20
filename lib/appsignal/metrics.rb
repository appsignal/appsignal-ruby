# frozen_string_literal: true

require "appsignal/metrics/extension_backend"
require "appsignal/metrics/opentelemetry_backend"

module Appsignal
  # @!visibility private
  #
  # Dispatches custom-metric helper calls to the backend that matches the
  # active mode: the agent-backed extension in normal operation, or the
  # OpenTelemetry SDK when `collector_endpoint` is configured.
  module Metrics
    class << self
      def backend
        if Appsignal.config&.collector_mode?
          OpenTelemetryBackend
        else
          ExtensionBackend
        end
      end
    end
  end
end
