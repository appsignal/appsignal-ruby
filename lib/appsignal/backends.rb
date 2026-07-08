# frozen_string_literal: true

module Appsignal
  # @!visibility private
  #
  # Looks up the active backend for each AppSignal subsystem. In normal
  # operation, subsystems route through the C-extension (and its agent).
  # When collector mode is configured and the OpenTelemetry SDK has booted
  # successfully, supported subsystems route through OTel instead.
  #
  # Centralizes the mode-check so per-subsystem call sites don't repeat the
  # "if collector? then OTel else Extension" branch. Future subsystems plug
  # in by adding one more lookup method here.
  module Backends
    class << self
      private

      def collector?
        Appsignal.config&.collector_mode? || false
      end
    end
  end
end
