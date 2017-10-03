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

        display_class, display_method = job.display_class.split(/\.|#/, 2)
        params = Appsignal::Utils::ParamsSanitizer.sanitize(
          job.display_args,
          :filter_parameters => Appsignal.config[:filter_parameters]
        )
        
        Appsignal.monitor_transaction(
          "perform_job.sidekiq",
          :class       => display_class,
          :method      => display_method || "perform",
          :metadata    => formatted_metadata(item),
          :params      => params,
          :queue_start => job.enqueued_at,
          :queue_time  => job.latency.to_f * 1000
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
        require "sidekiq/api"
        ::Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Hooks::SidekiqPlugin
          end
        end
      end
    end
  end
end
