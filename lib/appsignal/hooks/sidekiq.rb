require "yaml"

module Appsignal
  class Hooks
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

    # @api private
    class SidekiqPlugin # rubocop:disable Metrics/ClassLength
      include Appsignal::Hooks::Helpers

      UNKNOWN_ACTION_NAME = "unknown".freeze
      JOB_KEYS = %w[
        args backtrace class created_at enqueued_at error_backtrace error_class
        error_message failed_at jid retried_at retry wrapped
      ].freeze

      def call(_worker, item, _queue)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(
            :queue_start => item["enqueued_at"]
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
          transaction.set_action_if_nil(formatted_action_name(item))
          transaction.params = filtered_arguments(item)
          formatted_metadata(item).each do |key, value|
            transaction.set_metadata key, value
          end
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
        end
      end

      private

      def formatted_action_name(job)
        sidekiq_action_name = parse_action_name(job)
        complete_action = sidekiq_action_name =~ /\.|#/
        if complete_action || sidekiq_action_name == UNKNOWN_ACTION_NAME
          return sidekiq_action_name
        end
        "#{sidekiq_action_name}#perform"
      end

      def filtered_arguments(job)
        Appsignal::Utils::ParamsSanitizer.sanitize(
          parse_arguments(job),
          :filter_parameters => Appsignal.config[:filter_parameters]
        )
      end

      def formatted_metadata(item)
        {}.tap do |hash|
          (item || {}).each do |key, value|
            next if JOB_KEYS.include?(key)
            hash[key] = truncate(string_or_inspect(value))
          end
        end
      end

      # Based on: https://github.com/mperham/sidekiq/blob/63ee43353bd3b753beb0233f64865e658abeb1c3/lib/sidekiq/api.rb#L316-L334
      def parse_action_name(job)
        args = job.fetch("args", [])
        job_class = job["class"]
        case job_class
        when "Sidekiq::Extensions::DelayedModel"
          safe_load(args[0], job_class) do |target, method, _|
            "#{target.class}##{method}"
          end
        when /\ASidekiq::Extensions::Delayed/
          safe_load(args[0], job_class) do |target, method, _|
            "#{target}.#{method}"
          end
        when "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
          wrapped_job = job["wrapped"]
          if wrapped_job
            parse_active_job_action_name_from_wrapped job
          else
            parse_active_job_action_name_from_arguments job
          end
        else
          job_class
        end
      end

      # Return the ActiveJob wrapped job name.
      #
      # Returns "unknown" if no acceptable job class name could be found.
      #
      # @example Payload with "wrapped" value
      #   {
      #     "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
      #     "wrapped" => "MyWrappedJob",
      #     # ...
      #   }
      def parse_active_job_action_name_from_wrapped(job)
        job_class = job["wrapped"]
        case job_class
        when "ActionMailer::DeliveryJob"
          extract_action_mailer_name job["args"]
        when String
          job_class
        else
          unknown_action_name_for job
        end
      end

      # Return the ActiveJob job name based on the job's arguments.
      #
      # Returns "unknown" if no acceptable job class name could be found.
      #
      # @example Payload without "wrapped" value
      #   {
      #     "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
      #     "args" => [{
      #       "job_class" => "MyWrappedJob",
      #       # ...
      #     }]
      #     # ...
      #   }
      def parse_active_job_action_name_from_arguments(job)
        args = job.fetch("args", [])
        first_arg = args[0]
        if first_arg == "ActionMailer::DeliveryJob"
          extract_action_mailer_name args
        elsif active_job_payload?(first_arg)
          first_arg["job_class"]
        else
          unknown_action_name_for job
        end
      end

      # Checks if the first argument in the job payload is an ActiveJob payload.
      def active_job_payload?(arg)
        arg.is_a?(Hash) && arg["job_class"].is_a?(String)
      end

      def unknown_action_name_for(job)
        Appsignal.logger.debug \
          "Unable to determine an action name from Sidekiq payload: #{job}"
        UNKNOWN_ACTION_NAME
      end

      def extract_action_mailer_name(args)
        # Returns in format: MailerClass#mailer_method
        args[0]["arguments"][0..1].join("#")
      end

      # Based on: https://github.com/mperham/sidekiq/blob/63ee43353bd3b753beb0233f64865e658abeb1c3/lib/sidekiq/api.rb#L336-L358
      def parse_arguments(job)
        args = job.fetch("args", [])
        case job["class"]
        when /\ASidekiq::Extensions::Delayed/
          safe_load(args[0], args) do |_, _, arg|
            arg
          end
        when "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
          is_wrapped = job["wrapped"]
          first_arg = args[0]
          job_args =
            if is_wrapped || active_job_payload?(first_arg)
              first_arg["arguments"]
            else
              []
            end
          if (is_wrapped || first_arg) == "ActionMailer::DeliveryJob"
            # Remove MailerClass, mailer_method and "deliver_now"
            job_args.drop(3)
          else
            job_args
          end
        else
          # Sidekiq Enterprise argument encryption.
          # More information: https://github.com/mperham/sidekiq/wiki/Ent-Encryption
          if job["encrypt".freeze]
            # No point in showing 150+ bytes of random garbage
            args[-1] = "[encrypted data]".freeze
          end
          args
        end
      end

      # Based on: https://github.com/mperham/sidekiq/blob/63ee43353bd3b753beb0233f64865e658abeb1c3/lib/sidekiq/api.rb#L403-L412
      def safe_load(content, default)
        yield(*YAML.load(content))
      rescue => error
        # Sidekiq issue #1761: in dev mode, it's possible to have jobs enqueued
        # which haven't been loaded into memory yet so the YAML can't be
        # loaded.
        Appsignal.logger.warn "Unable to load YAML: #{error.message}"
        default
      end
    end
  end
end
