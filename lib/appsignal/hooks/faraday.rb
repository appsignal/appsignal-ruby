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

        Appsignal::Environment.report_enabled("faraday")
      end
    end
  end
end
