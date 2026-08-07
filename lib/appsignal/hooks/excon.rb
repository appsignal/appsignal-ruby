# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ExconHook < Appsignal::Hooks::Hook
      register :excon

      def dependencies_present?
        Appsignal.config && defined?(::Excon) && Appsignal.config[:instrument_excon]
      end

      def install
        require "appsignal/integrations/excon"
        # Instrument the request at the connection, rather than by registering
        # AppSignal as Excon's instrumentor. An instrumentor is told about a
        # request in pieces, none of which covers the wait for the response, and
        # there is only room for one of them, so registering ours would replace
        # any the application set up itself.
        ::Excon::Connection.prepend Appsignal::Integrations::ExconIntegration

        Appsignal::Environment.report_enabled("excon")
      end
    end
  end
end
