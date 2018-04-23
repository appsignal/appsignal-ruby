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
        args = job["args"]
        case job["class"]
        when "Sidekiq::Extensions::DelayedModel"
          safe_load(job["args"][0], job["class"]) do |target, method, _|
            "#{target.class}##{method}"
          end
        when /\ASidekiq::Extensions::Delayed/
          safe_load(job["args"][0], job["class"]) do |target, method, _|
            "#{target}.#{method}"
          end
        when "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
          job_class = job["wrapped"] || args[0]
          case job_class
          when "ActionMailer::DeliveryJob"
            # MailerClass#mailer_method
            args[0]["arguments"][0..1].join("#")
          when String
            job_class
          else
            Appsignal.logger.debug \
              "Unable to determine an action name from Sidekiq payload: #{job}"
            UNKNOWN_ACTION_NAME
          end
        else
          job["class"]
        end
      end

      # Based on: https://github.com/mperham/sidekiq/blob/63ee43353bd3b753beb0233f64865e658abeb1c3/lib/sidekiq/api.rb#L336-L358
      def parse_arguments(job)
        args = job["args"]
        case job["class"]
        when /\ASidekiq::Extensions::Delayed/
          safe_load(args[0], args) do |_, _, arg|
            arg
          end
        when "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
          is_wrapped = job["wrapped"]
          job_args = is_wrapped ? args[0]["arguments"] : []
          if (is_wrapped || args[0]) == "ActionMailer::DeliveryJob"
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
