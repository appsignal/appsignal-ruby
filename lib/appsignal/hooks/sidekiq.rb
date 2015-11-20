module Appsignal
  class Hooks
    class SidekiqPlugin
      def job_keys
        @job_keys ||= Set.new(%w(
            class args retried_at failed_at
            error_message error_class backtrace
            error_backtrace enqueued_at retry
        ))
      end

      def call(worker, item, queue)
        Appsignal.monitor_transaction(
          'perform_job.sidekiq',
          :class       => item['wrapped'] || item['class'],
          :method      => 'perform',
          :metadata    => formatted_metadata(item),
          :params      => format_args(item['args']),
          :queue_start => item['enqueued_at']
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

      def string_or_inspect(string_or_other)
        if string_or_other.is_a?(String)
          string_or_other
        else
          string_or_other.inspect
        end
      end

      def format_args(args)
        args.map do |arg|
          truncate(string_or_inspect(arg))
        end
      end

      def truncate(text)
        text.size > 200 ? "#{text[0...197]}..." : text
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
