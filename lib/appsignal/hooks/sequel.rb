module Appsignal
  class Hooks
    module SequelExtension
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

    class SequelHook < Appsignal::Hooks::Hook
      register :sequel

      def dependencies_present?
        defined?(::Sequel::Database) &&
          Appsignal.config &&
          Appsignal.config[:instrument_sequel]
      end

      def install
        # Register the extension...
        ::Sequel::Database.register_extension(
          :appsignal_integration,
          Appsignal::Hooks::SequelExtension
        )

        # ... and automatically add it to future instances.
        ::Sequel::Database.extension(:appsignal_integration)
      end
    end
  end
end
