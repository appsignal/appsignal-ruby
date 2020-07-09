# frozen_string_literal: true

require "yaml"

module Appsignal
  class Hooks
    class SidekiqHook < Appsignal::Hooks::Hook
      register :sidekiq

      def dependencies_present?
        defined?(::Sidekiq)
      end

      def install
        require "appsignal/probes/sidekiq"
        Appsignal::Minutely.probes.register :sidekiq, Appsignal::Probes::SidekiqProbe

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

      EXCLUDED_JOB_KEYS = %w[
        args backtrace class created_at enqueued_at error_backtrace error_class
        error_message failed_at jid retried_at retry wrapped
      ].freeze

      def call(_worker, item, _queue)
        job_status = nil
        transaction = Appsignal::Transaction.create(
          item["jid"],
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(
            :queue_start => item["enqueued_at"]
          )
        )

        Appsignal.instrument "perform_job.sidekiq" do
          begin
            yield
          rescue Exception => exception # rubocop:disable Lint/RescueException
            job_status = :failed
            transaction.set_error(exception)
            raise exception
          end
        end
      ensure
        if transaction
          transaction.set_action_if_nil(formatted_action_name(item))

          params = filtered_arguments(item)
          transaction.params = params if params

          formatted_metadata(item).each do |key, value|
            transaction.set_metadata key, value
          end
          transaction.set_http_or_background_queue_start
          Appsignal::Transaction.complete_current!
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
