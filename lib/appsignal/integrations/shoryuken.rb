module Appsignal
  module Integrations
    class ShoryukenMiddleware
      def call(worker_instance, queue, sqs_msg, body)
        metadata = {
          :queue => queue
        }
        metadata.merge!(body.except('job_class', 'queue_name', 'arguments'))
        metadata.merge!(sqs_msg.attributes)

        options = {
          :class => body['job_class'],
          :method => 'perform',
          :metadata => metadata
        }
        options[:params] = body['arguments'] if body.key?('arguments')
        options[:queue_start] = Time.at(sqs_msg.attributes['SentTimestamp'].to_i / 1000) if sqs_msg.attributes.key?('SentTimestamp')

        Appsignal.monitor_transaction('perform_job.shoryuken', options) do
          yield
        end
      end
    end
  end
end