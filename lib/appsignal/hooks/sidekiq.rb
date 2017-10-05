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

        # job.display_class needs to be called before job.display_args,
        # see https://github.com/appsignal/appsignal-ruby/pull/348#issuecomment-333629065
        job_action_name = job.display_class
        unless job_action_name =~ /[\.#]+/
          # Add #perform as default method name for job names without a method
          # name
          job_action_name = "#{job_action_name}#perform"
        end
        params = Appsignal::Utils::ParamsSanitizer.sanitize(
          job.display_args,
          :filter_parameters => Appsignal.config[:filter_parameters]
        )

        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(
            :queue_start => job.enqueued_at,
            :queue_time  => job.latency.to_f * 1000
          )
        )

        Appsignal.instrument "perform_job.sidekiq" do
          begin
            yield
          rescue Exception => exception # rubocop:disable Lint/RescueException
            transaction.set_error(exception)
            raise exception
          end
        end
      ensure
        if transaction
          transaction.set_action_if_nil(job_action_name)
          transaction.params = params
          formatted_metadata(item).each do |key, value|
            transaction.set_metadata key, value
          end
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end

      private

      def formatted_metadata(item)
        {}.tap do |hash|
          item.each do |key, value|
            next if job_keys.include?(key)
            hash[key] = truncate(string_or_inspect(value))
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
