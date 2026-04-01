# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class PgbusHook < Appsignal::Hooks::Hook
      register :pgbus

      def dependencies_present?
        defined?(::Pgbus::ActiveJob::Executor)
      end

      def install
        require "appsignal/integrations/pgbus"
        ::Pgbus::ActiveJob::Executor.prepend(
          Appsignal::Integrations::PgbusExecutorPlugin
        )
        ::Pgbus::EventBus::Handler.prepend(
          Appsignal::Integrations::PgbusHandlerPlugin
        )
      end
    end
  end
end
