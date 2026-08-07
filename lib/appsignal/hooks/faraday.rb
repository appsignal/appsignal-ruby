# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class FaradayHook < Appsignal::Hooks::Hook
      register :faraday

      def dependencies_present?
        defined?(::Faraday) && Appsignal.config && Appsignal.config[:instrument_faraday]
      end

      def install
        require "appsignal/integrations/faraday"
        ::Faraday::RackBuilder.prepend(Appsignal::Integrations::FaradayRackBuilderPatch)

        # This integration records the request itself, so Faraday's own
        # instrumentation middleware would report the same work again as a
        # `request.faraday` notification. Claim it so the generic notification
        # paths leave it alone.
        #
        # Claimed on install, so the claim lasts exactly as long as this
        # integration is recording the work.
        Appsignal::EventFormatter.register(
          "request.faraday",
          Appsignal::EventFormatter::RecordedElsewhere
        )

        Appsignal::Environment.report_enabled("faraday")
      end
    end
  end
end
