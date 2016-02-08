module Appsignal
  module Integrations
    module ResquePlugin
      def around_perform_resque_plugin(*args)
        Appsignal.monitor_single_transaction(
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
