module Appsignal
  class MongoInstrumentation
    def self.setup(logger)
      if defined?(Mongo::Logging)
        logger.info 'Adding instrumentation to Mongo::Logging'

        Mongo::Logging.module_eval do
          alias_method :instrument_without_notification, :instrument
          def instrument(name, payload={})
            ActiveSupport::Notifications.instrument(
              'query.mongodb',
              :query => payload.merge(:method => name)) do
                send :instrument_without_notification, name, payload do
                  yield
                end
            end
          end
        end
      end
    end
  end
end
