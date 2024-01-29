# frozen_string_literal: true

require "yaml"

module Appsignal
  module Integrations
    # Error handler for Sidekiq to report errors from jobs and internal Sidekiq
    # errors.
    #
    # @api private
    class SidekiqErrorHandler
      def call(exception, sidekiq_context, _sidekiq_config = nil)
        transaction =
          if Appsignal::Transaction.current?
            Appsignal::Transaction.current
          else
            # Sidekiq error outside of the middleware scope.
            # Can be a job JSON parse error or some other error happening in
            # Sidekiq.
            transaction =
              Appsignal::Transaction.create(
                SecureRandom.uuid, # Newly generated job id
                Appsignal::Transaction::BACKGROUND_JOB,
                Appsignal::Transaction::GenericRequest.new({})
              )
            transaction.set_action_if_nil("SidekiqInternal")
            transaction.set_metadata("sidekiq_error", sidekiq_context[:context])
            transaction.params = { :jobstr => sidekiq_context[:jobstr] }
            transaction
          end

        transaction.set_error(exception)
        Appsignal::Transaction.complete_current!
      end
    end

    # @api private
    class SidekiqMiddleware
      include Appsignal::Hooks::Helpers

      EXCLUDED_JOB_KEYS = %w[
        args backtrace class created_at enqueued_at error_backtrace error_class
        error_message failed_at jid retried_at retry wrapped
      ].freeze

      def call(_worker, item, _queue, &block)
        job_status = nil
        transaction = Appsignal::Transaction.create(
          item["jid"],
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(
            :queue_start => item["enqueued_at"]
          )
        )
        transaction.set_action_if_nil(formatted_action_name(item))

        formatted_metadata(item).each do |key, value|
          transaction.set_metadata key, value
        end

        Appsignal.instrument "perform_job.sidekiq", &block
      rescue Exception => exception # rubocop:disable Lint/RescueException
        job_status = :failed
        raise exception
      ensure
        if transaction
          params = filtered_arguments(item)
          transaction.params = params if params

          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current! unless exception

          queue = item["queue"] || "unknown"
          if job_status
            increment_counter "queue_job_count", 1,
              :queue => queue,
              :status => job_status
          end
          increment_counter "queue_job_count", 1,
            :queue => queue,
            :status => :processed
        end
      end

      private

      def increment_counter(key, value, tags = {})
        Appsignal.increment_counter "sidekiq_#{key}", value, tags
      end

      def formatted_action_name(job)
        sidekiq_action_name = parse_action_name(job)
        return unless sidekiq_action_name

        complete_action = sidekiq_action_name =~ /\.|#/
        return sidekiq_action_name if complete_action

        "#{sidekiq_action_name}#perform"
      end

      def filtered_arguments(job)
        arguments = parse_arguments(job)
        return unless arguments

        Appsignal::Utils::HashSanitizer.sanitize(
          arguments,
          Appsignal.config[:filter_parameters]
        )
      end

      def formatted_metadata(item)
        {}.tap do |hash|
          (item || {}).each do |key, value|
            next if EXCLUDED_JOB_KEYS.include?(key)

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
        else
          job_class
        end
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
          nil # Set in the ActiveJob integration
        else
          # Sidekiq Enterprise argument encryption.
          # More information: https://github.com/mperham/sidekiq/wiki/Ent-Encryption
          if job["encrypt"]
            # No point in showing 150+ bytes of random garbage
            args[-1] = "[encrypted data]"
          end
          args
        end
      end

      # Based on: https://github.com/mperham/sidekiq/blob/63ee43353bd3b753beb0233f64865e658abeb1c3/lib/sidekiq/api.rb#L403-L412
      def safe_load(content, default)
        if YAML::VERSION >= "4.0.0"
          yield(*YAML.unsafe_load(content))
        else
          yield(*YAML.load(content))
        end
      rescue => error
        # Sidekiq issue #1761: in dev mode, it's possible to have jobs enqueued
        # which haven't been loaded into memory yet so the YAML can't be
        # loaded.
        Appsignal.internal_logger.warn "Unable to load YAML: #{error.message}"
        default
      end
    end
  end
end
