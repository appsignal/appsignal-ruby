module Appsignal
  class TireInstrumentation
    def self.setup(logger)
      if Appsignal.config[:instrumentations] &&
         Appsignal.config[:instrumentations]['tire'] &&
         defined?(Tire::Search::Search)
        logger.info 'Adding instrumentation to Tire::Search::Search'

        Tire::Search::Search.class_eval do
          alias_method :perform_without_notification, :perform
          def perform
            ActiveSupport::Notifications.instrument(
              'query.elasticsearch',
              :params => self.params,
              :json => self.to_hash) do
              send :perform_without_notification
            end
          end
        end
      end
    end
  end
end
