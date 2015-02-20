if defined?(::Delayed::Plugin)
  Appsignal.logger.info('Loading Delayed Job integration')

  module Appsignal
    module Integrations
      class DelayedPlugin < ::Delayed::Plugin
        callbacks do |lifecycle|
          lifecycle.around(:invoke_job) do |job, &block|
            invoke_with_instrumentation(job, block)
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
            :class => class_name,
            :method => method_name,
            :priority => job.priority,
            :attempts => job.attempts,
            :queue => job.queue,
            :queue_start => job.created_at
          ) do
            block.call(job)
          end
        end
      end
    end
  end
  ::Delayed::Worker.plugins << Appsignal::Integrations::DelayedPlugin
end
