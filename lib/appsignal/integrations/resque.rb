Appsignal.logger.debug('moo')
if defined?(::Resque)
  Appsignal.logger.info('Loading Resque integration')

  module Appsignal
    module Integrations
      module ResquePlugin

        def around_perform_resque_plugin(*args)
          Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
          ActiveSupport::Notifications.instrument(
            'perform_job.resque',
            :class => self.to_s,
            :method => 'perform'
          ) do
            yield
          end
        rescue Exception => exception
          unless Appsignal.is_ignored_exception?(exception)
            Appsignal::Transaction.current.add_exception(exception)
          end
          raise exception
        ensure
          Appsignal::Transaction.current.complete!
        end
      end
    end
  end

end
