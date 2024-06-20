# frozen_string_literal: true

module Appsignal
  class Hooks
    class SidekiqHook < Appsignal::Hooks::Hook
      register :sidekiq

      def self.version_5_1_or_higher?
        @version_5_1_or_higher ||=
          if dependencies_present?
            Gem::Version.new(::Sidekiq::VERSION) >= Gem::Version.new("5.1.0")
          else
            false
          end
      end

      def self.dependencies_present?
        defined?(::Sidekiq)
      end

      def dependencies_present?
        self.class.dependencies_present?
      end

      def install
        require "appsignal/integrations/sidekiq"
        Appsignal::Probes.register :sidekiq, Appsignal::Probes::SidekiqProbe

        ::Sidekiq.configure_server do |config|
          config.error_handlers <<
            Appsignal::Integrations::SidekiqErrorHandler.new
          if config.respond_to? :death_handlers
            config.death_handlers <<
              Appsignal::Integrations::SidekiqDeathHandler.new
          end

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
