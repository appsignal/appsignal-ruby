if defined?(::Resque)
  Appsignal.logger.info('Loading Resque integration')

  module Appsignal
    module Integrations
      module ResquePlugin
        def around_perform_resque_plugin(*args)
          Appsignal.monitor_transaction(
            'perform_job.resque',
            :class => self.to_s,
            :method => 'perform'
          ) do
            yield
          end
        end
      end
    end
  end

  # Extend the default job class with AppSignal instrumentation
  Resque::Job.send(:extend, Appsignal::Integrations::ResquePlugin)
end
