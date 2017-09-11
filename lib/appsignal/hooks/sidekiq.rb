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
        job = ::Sidekiq::Job.new(item)

        Appsignal.monitor_transaction(
          "perform_job.sidekiq",
          :class       => job.display_class.split('.', 2)[0],
          :method      => job.display_class.split('.', 2)[1],
          :metadata    => formatted_metadata(item),
          :params      => job.display_args,
          :queue_start => job.enqueued_at,
          :queue_time  => job.latency * 1000
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
