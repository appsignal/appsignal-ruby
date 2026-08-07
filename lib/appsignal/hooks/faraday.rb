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

        # This integration records the request itself, as a client event that
        # also injects trace context. Faraday's own instrumentation middleware,
        # if the user added it, emits a `request.faraday` notification nested
        # inside that event. Claim it so that the generic notification paths
        # leave it alone.
        #
        # Claimed on install, so that the event is only claimed while this
        # integration is recording it. With Faraday instrumentation turned off
        # there is nothing for the notification to duplicate, so it is left to
        # be recorded like any other.
        Appsignal::EventFormatter.register(
          "request.faraday",
          Appsignal::EventFormatter::RecordedElsewhere
        )

        Appsignal::Environment.report_enabled("faraday")
      end
    end
  end
end
