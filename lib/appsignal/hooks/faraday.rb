# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class FaradayHook < Appsignal::Hooks::Hook
      register :faraday

      # This integration records the request itself, so Faraday's own
      # instrumentation middleware would report the same work again as a
      # `request.faraday` notification. Claim it so the generic notification
      # paths leave it alone.
      #
      # Claimed here, when this file is required, rather than in `install`.
      # `install` only runs when Faraday instrumentation is turned on, but a
      # customer who turns it off does not want to see the native
      # notification reported instead. This call does not touch any
      # `Faraday` constant, so it is safe to run even when the library is not
      # present.
      Appsignal::EventFormatter.register(
        "request.faraday",
        Appsignal::EventFormatter::RecordedElsewhere
      )

      def dependencies_present?
        defined?(::Faraday) && Appsignal.config && Appsignal.config[:instrument_faraday]
      end

      def install
        require "appsignal/integrations/faraday"
        ::Faraday::RackBuilder.prepend(Appsignal::Integrations::FaradayRackBuilderPatch)

        Appsignal::Environment.report_enabled("faraday")
      end
    end
  end
end
