module Appsignal
  class Hooks
    # @api private
    class ShoryukenMiddleware
      def call(worker_instance, queue, sqs_msg, body)
        metadata = { :queue => queue }.merge(sqs_msg.attributes)
        options = {
          :class => worker_instance.class.name,
          :method => "perform",
          :metadata => metadata
        }

        args = body.is_a?(Hash) ? body : { :params => body }
        options[:params] = Appsignal::Utils::ParamsSanitizer.sanitize args,
          :filter_parameters => Appsignal.config[:filter_parameters]

        if sqs_msg.attributes.key?("SentTimestamp")
          options[:queue_start] = Time.at(sqs_msg.attributes["SentTimestamp"].to_i / 1000)
        end

        Appsignal.monitor_transaction("perform_job.shoryuken", options) do
          yield
        end
      end
    end

    class ShoryukenHook < Appsignal::Hooks::Hook
      register :shoryuken

      def dependencies_present?
        defined?(::Shoryuken)
      end

      def install
        ::Shoryuken.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Hooks::ShoryukenMiddleware
          end
        end
      end
    end
  end
end
