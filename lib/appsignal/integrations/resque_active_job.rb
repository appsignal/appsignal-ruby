module Appsignal
  module Integrations
    # @api private
    module ResqueActiveJobPlugin
      include Appsignal::Hooks::Helpers

      def self.included(base)
        base.class_eval do
          around_perform do |job, block|
            Appsignal.monitor_single_transaction(
              "perform_job.resque",
              :class    => job.class.to_s,
              :method   => "perform",
              :params   => job.format_args(job.arguments),
              :metadata => {
                :id       => job.job_id,
                :queue    => job.queue_name
              }
            ) do
              block.call
            end
          end
        end
      end
    end
  end
end
