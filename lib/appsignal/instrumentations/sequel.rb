if defined?(::Sequel)
  Appsignal.logger.info("Loading Sequel (#{ Sequel::VERSION }) integration")

  module Appsignal
    module Integrations
      module Sequel
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
      end # Sequel
    end # Integrations
  end # Appsignal

  # Register the extension...
  Sequel::Database.register_extension(
    :appsignal_integration,
    Appsignal::Integrations::Sequel
  )

  # ... and automatically add it to future instances.
  Sequel::Database.extension(:appsignal_integration)
end
