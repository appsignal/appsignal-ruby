# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class HttpHook < Appsignal::Hooks::Hook
      register :http_rb

      def dependencies_present?
        defined?(HTTP::Client) && Appsignal.config && Appsignal.config[:instrument_http_rb]
      end

      def install
        require "appsignal/integrations/http"
        # `perform` has the same signature in http5 and http6, so a single
        # prepend module works for both.
        HTTP::Client.prepend Appsignal::Integrations::HttpIntegration

        Appsignal::Environment.report_enabled("http_rb")
      end
    end
  end
end
