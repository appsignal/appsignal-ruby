# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class HttpHook < Appsignal::Hooks::Hook
      register :http_rb

      def self.http6_or_higher?
        Gem::Version.new(HTTP::VERSION) >= Gem::Version.new("6.0.0")
      end

      def dependencies_present?
        defined?(HTTP::Client) && Appsignal.config && Appsignal.config[:instrument_http_rb]
      end

      def install
        require "appsignal/integrations/http"
        integration =
          if self.class.http6_or_higher?
            Appsignal::Integrations::HttpIntegration::KeywordOptions
          else
            Appsignal::Integrations::HttpIntegration::HashOptions
          end
        HTTP::Client.prepend integration

        Appsignal::Environment.report_enabled("http_rb")
      end
    end
  end
end
