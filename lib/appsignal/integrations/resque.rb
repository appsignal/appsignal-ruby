if defined?(::Resque)
  Appsignal.logger.info('Loading Resque integration')

  module Appsignal
    module Integrations
      class ResquePlugin
        def around_perform(worker, item, queue, proc)
          Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
          ActiveSupport::Notifications.instrument(
            'perform_job.resque',
            :class => item['class'],
            :method => 'perform',
            :attempts => item['retry_count'],
            :queue => item['queue'],
            :queue_start => item['enqueued_at']
          ) do
            proc.call
          end
        rescue Exception => exception
          unless Appsignal.is_ignored_exception?(exception)
            Appsignal::Transaction.current.add_exception(exception)
          end
          raise exception
        ensure
          Appsignal::Transaction.current.complete!
        end

        def on_failure(exception, worker, queue, payload)
          return unless Appsignal.is_ignored_exception?(exception)
          Appsignal::Transaction.current.add_exception(exception)
        end
      end
    end
  end

end
