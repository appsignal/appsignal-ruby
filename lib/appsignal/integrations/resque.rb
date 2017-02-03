module Appsignal
  module Integrations
    # @api private
    module ResquePlugin
      # Do not use this file as a template for your own background processor
      # Resque is an exception to the rule and the code below causes the
      # extension to shut itself down after a single job.
      # see http://docs.appsignal.com/background-monitoring/custom.html
      def around_perform_resque_plugin(*_args)
        Appsignal.monitor_single_transaction(
          "perform_job.resque",
          :class => to_s,
          :method => "perform"
        ) do
          yield
        end
      end
    end
  end
end
