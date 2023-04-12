# frozen_string_literal: true

module Appsignal
  class Hooks
    class SidekiqHook < Appsignal::Hooks::Hook
      register :sidekiq

      def dependencies_present?
        defined?(::Sidekiq)
      end

      def install
        require "appsignal/integrations/sidekiq"
        Appsignal::Minutely.probes.register :sidekiq, Appsignal::Probes::SidekiqProbe

        ::Sidekiq.configure_server do |config|
          config.error_handlers <<
            Appsignal::Integrations::SidekiqErrorHandler.new

          config.server_middleware do |chain|
            if chain.respond_to? :prepend
              chain.prepend Appsignal::Integrations::SidekiqMiddleware
            else
              chain.add Appsignal::Integrations::SidekiqMiddleware
            end
          end
        end
      end
    end
  end
end
