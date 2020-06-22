# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ResqueActiveJobPlugin
      include Appsignal::Hooks::Helpers

      def self.included(base)
        base.class_eval do
          around_perform do |job, block|
            params = Appsignal::Utils::HashSanitizer.sanitize(
              job.arguments,
              Appsignal.config[:filter_parameters]
            )

            queue_start =
              if job.respond_to?(:enqueued_at) && job.enqueued_at
                Time.parse(job.enqueued_at).utc
              end

            Appsignal.monitor_single_transaction(
              "perform_job.resque",
              :class       => job.class.to_s,
              :method      => "perform",
              :params      => params,
              :queue_start => queue_start,
              :metadata    => {
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
