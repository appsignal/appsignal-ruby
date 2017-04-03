module Appsignal
  class Hooks
    # @api private
    class ShoryukenMiddleware
      EXCLUDE_KEYS = %w(job_class queue_name arguments).freeze

      def call(_worker_instance, queue, sqs_msg, body)
        metadata = {
          :queue => queue
        }

        options = {
          :method => "perform",
          :metadata => metadata
        }

        if body.is_a?(Hash)
          body = body.each_with_object({}) { |(key, value), object| object[key.to_s] = value }
          metadata.merge!(body.reject { |key, _value| EXCLUDE_KEYS.member?(key) })
          options[:class] = body["job_class"]
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
