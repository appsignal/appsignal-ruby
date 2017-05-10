module Appsignal
  class Hooks
    # @api private
    class ShoryukenMiddleware
      def call(_worker_instance, queue, sqs_msg, body)
        metadata = {
          :queue => queue
        }

        options = {
          :method => "perform",
          :metadata => metadata
        }

        if body.respond_to?(:reject)
          exclude_keys = [:job_class, :queue_name, :arguments]
          metadata.merge!(body.reject { |key| exclude_keys.member?(key.to_sym) })
          options[:class] = body["job_class"] # can it be a symbol? Shoryuken allows custom serialization
          options[:params] = body["arguments"] if body.key?("arguments")
        else
          metadata[:body] = body
        end

        metadata.merge!(sqs_msg.attributes)

        options[:queue_start] = Time.at(sqs_msg.attributes["SentTimestamp"].to_i / 1000) if sqs_msg.attributes.key?("SentTimestamp")

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
