if defined?(::Sidekiq)
  Appsignal.logger.info('Loading Sidekiq integration')

  module Appsignal
    module Integrations
      class SidekiqPlugin
        def call(worker, item, queue)
          Appsignal.monitor_transaction(
            'perform_job.sidekiq',
            :class => item['class'],
            :method => 'perform',
            :attempts => item['retry_count'],
            :queue => item['queue'],
            :queue_start => item['enqueued_at']
          ) do
            yield
          end
        end
      end
    end
  end

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Appsignal::Integrations::SidekiqPlugin
    end
  end
end
