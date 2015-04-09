if defined?(::Sequel)
  Appsignal.logger.info("Loading Sequel (#{ Sequel::VERSION }) integration")

  module Appsignal
    module Integrations
      module Sequel
        # Add query instrumentation
        def log_yield(sql, args = nil)
          name    = 'sql.sequel'
          payload = {:sql => sql, :args => args}

          ActiveSupport::Notifications.instrument(name, payload) { yield }
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
