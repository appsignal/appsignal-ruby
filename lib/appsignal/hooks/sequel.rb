module Appsignal
  class Hooks
    module SequelExtension
      # Add query instrumentation
      def log_yield(sql, args = nil)

        # We'd like to get full sql queries in the payloads as well. To do
        # that we need to find out a way to ask Sequel which quoting strategy
        # is used by the adapter. We can then do something similar to the AR
        # formatter.

        ActiveSupport::Notifications.instrument('sql.sequel') do
          yield
        end
      end
    end

    class SequelHook < Appsignal::Hooks::Hook
      register :sequel

      def dependencies_present?
        defined?(::Sequel::Database) &&
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
