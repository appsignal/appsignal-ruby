module Appsignal
  class Hooks
    # @api private
    class SidekiqPlugin
      include Appsignal::Hooks::Helpers

      def job_keys
        @job_keys ||= Set.new(%w(
          class args retried_at failed_at
          error_message error_class backtrace
          error_backtrace enqueued_at retry
          jid retry created_at wrapped
        ))
      end

      def call(_worker, item, _queue)
        args =
          if item["class"] == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
            item["args"].first["arguments"]
          else
            item["args"]
          end
        params = Appsignal::Utils::ParamsSanitizer.sanitize args,
          :filter_parameters => Appsignal.config[:filter_parameters]

        Appsignal.monitor_transaction(
          "perform_job.sidekiq",
          :class       => item["wrapped"] || item["class"],
          :method      => "perform",
          :metadata    => formatted_metadata(item),
          :params      => params,
          :queue_start => item["enqueued_at"],
          :queue_time  => (Time.now.to_f - item["enqueued_at"].to_f) * 1000
        ) do
          yield
        end
      end

      def formatted_metadata(item)
        {}.tap do |hsh|
          item.each do |key, val|
            hsh[key] = truncate(string_or_inspect(val)) unless job_keys.include?(key)
          end
        end
      end
    end

    class SidekiqHook < Appsignal::Hooks::Hook
      register :sidekiq

      def dependencies_present?
        defined?(::Sidekiq)
      end

      def install
        ::Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Hooks::SidekiqPlugin
          end
        end
      end
    end
  end
end
