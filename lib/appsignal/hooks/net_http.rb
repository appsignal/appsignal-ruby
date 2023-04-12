# frozen_string_literal: true

require "net/http"

module Appsignal
  class Hooks
    # @api private
    class NetHttpHook < Appsignal::Hooks::Hook
      register :net_http

      def dependencies_present?
        Appsignal.config && Appsignal.config[:instrument_net_http]
      end

      def install
        require "appsignal/integrations/net_http"
        Net::HTTP.prepend Appsignal::Integrations::NetHttpIntegration

        Appsignal::Environment.report_enabled("net_http")
      end
    end
  end
end
