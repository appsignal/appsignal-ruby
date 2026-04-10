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

        if defined?(::Pgbus::Streams::Stream)
          ::Pgbus::Streams::Stream.prepend(
            Appsignal::Integrations::PgbusStreamPlugin
          )
        end

        if defined?(::Pgbus::Web::DataSource)
          require "appsignal/probes/pgbus"
          Appsignal::Probes.register :pgbus, Appsignal::Probes::PgbusProbe
        end
      end
    end
  end
end
