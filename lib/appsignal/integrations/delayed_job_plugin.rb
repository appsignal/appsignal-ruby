# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class DelayedJobPlugin < ::Delayed::Plugin
      extend Appsignal::Hooks::Helpers

      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, &block|
          invoke_with_instrumentation(job, block)
        end

        lifecycle.after(:execute) do |_execute|
          Appsignal.stop("delayed job")
        end
      end

      def self.invoke_with_instrumentation(job, block)
        payload = job.payload_object

        if payload.respond_to? :job_data
          # ActiveJob
          job_data = payload.job_data
          args = job_data.fetch("arguments", {})
          class_name = job_data["job_class"]
          method_name = "perform"
        else
          # Delayed Job
          args = extract_value(job.payload_object, :args, {})
          class_and_method_name = extract_value(job.payload_object, :appsignal_name, job.name)
          class_name, method_name = class_and_method_name.split("#")
        end

        params = Appsignal::Utils::HashSanitizer.sanitize(
          args,
          Appsignal.config[:filter_parameters]
        )

        Appsignal.monitor_transaction(
          "perform_job.delayed_job",
          :class    => class_name,
          :method   => method_name,
          :metadata => {
            :id       => extract_value(job, :id, nil, true),
            :queue    => extract_value(job, :queue),
            :priority => extract_value(job, :priority, 0),
            :attempts => extract_value(job, :attempts, 0)
          },
          :params      => params,
          :queue_start => extract_value(job, :run_at)
        ) do
          block.call(job)
        end
      end
    end
  end
end
