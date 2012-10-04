
    module Mongo
      module Logging
        alias_method "instrument_without_notification", 'instrument'
        def instrument(name, payload={})
          ActiveSupport::Notifications.instrument(
            'query.mongodb',
            :query => payload.merge(:method => name)) do
              send "instrument_without_notification", name, payload do
                yield
              end
          end
        end
      end
    end
