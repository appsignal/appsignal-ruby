# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    module SequelLogExtension
      # Add query instrumentation
      def log_yield(sql, args = nil)
        Appsignal.instrument(
          "sql.sequel",
          nil,
          sql,
          Appsignal::EventFormatter::SQL_BODY_FORMAT
        ) do
          super
        end
      end
    end

    module SequelLogConnectionExtension
      # Add query instrumentation
      def log_connection_yield(sql, conn, args = nil)
        Appsignal.instrument(
          "sql.sequel",
          nil,
          sql,
          Appsignal::EventFormatter::SQL_BODY_FORMAT
        ) do
          super
        end
      end
    end

    class SequelHook < Appsignal::Hooks::Hook
      register :sequel

      def dependencies_present?
        defined?(::Sequel::Database) &&
          Appsignal.config &&
          Appsignal.config[:instrument_sequel]
      end

      def install
        # Register the extension...
        if (::Sequel::MAJOR >= 4 && ::Sequel::MINOR >= 35) || ::Sequel::MAJOR >= 5
          ::Sequel::Database.register_extension(
            :appsignal_integration,
            Appsignal::Hooks::SequelLogConnectionExtension
          )
        else
          ::Sequel::Database.register_extension(
            :appsignal_integration,
            Appsignal::Hooks::SequelLogExtension
          )
        end

        # ... and automatically add it to future instances.
        ::Sequel::Database.extension(:appsignal_integration)

        Appsignal::Environment.report_enabled("sequel")
      end
    end
  end
end
