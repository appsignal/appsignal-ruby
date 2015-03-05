if defined?(::Sidekiq)
  Appsignal.logger.info('Loading Sidekiq integration')

  module Appsignal
    module Integrations
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
            :class       => item['class'],
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
          text.size > 100 ? "#{text[0...97]}..." : text
        end
      end
    end
  end

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Appsignal::Integrations::SidekiqPlugin
    end
  end
end
