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

  # Create a pipe for the workers to write to
  Resque.before_first_fork do
    Appsignal::Pipe.init
  end

  # In the fork, stop the normal agent startup
  # and stop listening to the pipe (we'll only use it for writing)
  Resque.after_fork do |job|
    Appsignal.agent.stop_thread
    Appsignal::Pipe.current.stop_listening!
  end

  # Extend the default job class with AppSignal instrumentation
  Resque::Job.send(:extend, Appsignal::Integrations::ResquePlugin)
end
