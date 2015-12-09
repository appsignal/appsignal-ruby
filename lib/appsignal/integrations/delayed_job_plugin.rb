module Appsignal
  class Hooks
    class DelayedJobPlugin < ::Delayed::Plugin
      include Appsignal::Hooks::Helpers

      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, &block|
          invoke_with_instrumentation(job, block)
        end

        lifecycle.after(:loop) do |loop|
          Appsignal.stop
        end
      end

      def self.invoke_with_instrumentation(job, block)
        class_and_method_name = if job.payload_object.respond_to?(:appsignal_name)
                                  job.payload_object.appsignal_name
                                else
                                  job.name
                                end
        class_name, method_name = class_and_method_name.split('#')

        Appsignal.monitor_transaction(
          'perform_job.delayed_job',
          :class    => class_name,
          :method   => method_name,
          :metadata => {
            :id       => job.id,
            :queue    => job.queue,
            :priority => job.priority || 0,
            :attempts => job.attempts || 0
          },
          :params      => format_args(job.payload_object.args),
          :queue_start => job.created_at
        ) do
          block.call(job)
        end
      end

      def self.format_args(args)
        args.map do |arg|
          self.truncate(self.string_or_inspect(arg))
        end
      end
    end
  end
end
