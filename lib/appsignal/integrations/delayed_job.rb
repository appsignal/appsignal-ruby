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
          begin
            Appsignal::Transaction.create(SecureRandom.uuid, ENV)
            class_name, method_name = job.name.split('#')
            ActiveSupport::Notifications.instrument(
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
          rescue Exception => exception
            Appsignal.add_exception(exception)
            raise exception
          ensure
            Appsignal::Transaction.complete_current!
          end
        end
      end
    end
  end
  ::Delayed::Worker.plugins << Appsignal::Integrations::DelayedPlugin
end
