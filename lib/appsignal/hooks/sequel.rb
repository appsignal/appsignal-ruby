module Appsignal
  class Hooks
    module SequelLogExtension
      # Add query instrumentation
      def log_yield(sql, args = nil)
        ActiveSupport::Notifications.instrument(
          'sql.sequel',
          :sql => sql
        ) do
          yield
        end
      end
    end

    module SequelLogConnectionExtension
      # Add query instrumentation
      def log_connection_yield(sql, conn, args = nil)
        ActiveSupport::Notifications.instrument(
          'sql.sequel',
          :sql => sql
        ) do
          yield
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
        if ::Sequel::MAJOR >= 4 && ::Sequel::MINOR >= 35
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
      end
    end
  end
end
