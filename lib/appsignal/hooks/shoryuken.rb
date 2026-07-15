# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ShoryukenHook < Appsignal::Hooks::Hook
      register :shoryuken

      def dependencies_present?
        defined?(::Shoryuken) && Appsignal.config && Appsignal.config[:instrument_shoryuken]
      end

      def install
        require "appsignal/integrations/shoryuken"

        ::Shoryuken.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Integrations::ShoryukenMiddleware
          end

          # Servers enqueue jobs too, so they need the client middleware that
          # records the enqueue event. Shoryuken only yields `configure_client`
          # outside the server, so register it here as well for enqueues from
          # within a worker.
          config.client_middleware do |chain|
            chain.add Appsignal::Integrations::ShoryukenClientMiddleware
          end
        end

        ::Shoryuken.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Appsignal::Integrations::ShoryukenClientMiddleware
          end
        end
      end
    end
  end
end
