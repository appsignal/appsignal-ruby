# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class UnicornHook < Appsignal::Hooks::Hook
      register :unicorn

      def dependencies_present?
        defined?(::Unicorn::HttpServer) &&
          defined?(::Unicorn::Worker)
      end

      def install
        require "appsignal/integrations/unicorn"
        ::Unicorn::HttpServer.prepend Appsignal::Integrations::UnicornIntegration::Server
        ::Unicorn::Worker.prepend Appsignal::Integrations::UnicornIntegration::Worker
      end
    end
  end
end
