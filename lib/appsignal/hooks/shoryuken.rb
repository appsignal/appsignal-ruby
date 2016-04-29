module Appsignal
  class Hooks
    class ShoryukenHook < Appsignal::Hooks::Hook
      register :shoryuken

      def dependencies_present?
        defined?(::Shoryuken)
      end

      def install
        require 'appsignal/integrations/shoryuken'

        ::Shoryuken.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Integrations::ShoryukenMiddleware
          end
        end
      end
    end
  end
end