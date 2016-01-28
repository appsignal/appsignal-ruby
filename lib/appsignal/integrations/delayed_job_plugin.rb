module Appsignal
  class Hooks
    class DelayedJobPlugin < ::Delayed::Plugin
      extend Appsignal::Hooks::Helpers

      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, &block|
          invoke_with_instrumentation(job, block)
        end

        lifecycle.after(:execute) do |execute|
          Appsignal.stop
        end
      end

      def self.invoke_with_instrumentation(job, block)
        if job.respond_to?(:payload_object)
          # Direct Delayed Job
          class_and_method_name = extract_value(job.payload_object, :appsignal_name, job.name)
          class_name, method_name = class_and_method_name.split('#')
          args = extract_value(job.payload_object, :args, {})
          job_data = job
        elsif job.respond_to?(:job_data)
          # Via ActiveJob
          class_name, method_name = job.job_data[:name].split('#')
          args = job.job_data[:args] || {}
          job_data = job.job_data
        end

        Appsignal.monitor_transaction(
          'perform_job.delayed_job',
          :class    => class_name,
          :method   => method_name,
          :metadata => {
            :id       => extract_value(job_data, :id, nil, true),
            :queue    => extract_value(job_data, :queue),
            :priority => extract_value(job_data, :priority, 0),
            :attempts => extract_value(job_data, :attempts, 0)
          },
          :params      => format_args(args),
          :queue_start => extract_value(job_data, :created_at)
        ) do
          block.call(job)
        end
      end
    end
  end
end
