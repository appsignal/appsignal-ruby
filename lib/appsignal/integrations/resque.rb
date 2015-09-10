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

  # Set up IPC
  Resque.before_first_fork do
    Appsignal::IPC::Server.start if Appsignal.active?
  end

  # In the fork, stop the normal agent startup
  # and stop listening to the server
  Resque.after_fork do |job|
    Appsignal::IPC.forked! if Appsignal.active?
  end
end
