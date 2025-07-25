# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ActiveJobHook < Appsignal::Hooks::Hook
      register :active_job

      def self.version_7_1_or_higher?
        @version_7_1_or_higher ||=
          if dependencies_present?
            major = ::ActiveJob::VERSION::MAJOR
            minor = ::ActiveJob::VERSION::MINOR
            major > 7 || (major == 7 && minor >= 1)
          else
            false
          end
      end

      def self.dependencies_present?
        defined?(::ActiveJob)
      end

      def dependencies_present?
        self.class.dependencies_present?
      end

      def install
        ActiveSupport.on_load(:active_job) do
          ::ActiveJob::Base
            .extend ::Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation

          next unless Appsignal::Hooks::ActiveJobHook.version_7_1_or_higher?

          # Only works on Active Job 7.1 and newer
          ::ActiveJob::Base.after_discard do |_job, exception|
            next unless Appsignal.config[:activejob_report_errors] == "discard"

            Appsignal::Transaction.current.set_error(exception)
          end
        end
      end

      module ActiveJobClassInstrumentation
        def execute(job) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          enqueued_at = job["enqueued_at"]
          queue_start = Time.parse(enqueued_at) if enqueued_at
          queue_time =
            if queue_start
              time_now = Time.now.utc
              # Calculate queue time and store it as milliseconds
              (time_now - queue_start) * 1_000
            end

          job_status = nil
          has_wrapper_transaction = Appsignal::Transaction.current?
          transaction =
            if has_wrapper_transaction
              Appsignal::Transaction.current
            else
              # No standalone integration started before ActiveJob integration.
              # We don't have a separate integration for this QueueAdapter like
              # we do for Sidekiq.
              #
              # Prefer job_id from provider, instead of ActiveJob's internal ID.
              Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)
            end

          if transaction
            transaction.add_params_if_nil(job["arguments"])

            transaction_tags = ActiveJobHelpers.transaction_tags_for(job)
            transaction.add_tags(transaction_tags)

            transaction.set_action(ActiveJobHelpers.action_name(job))
          end

          super
        rescue Exception => exception # rubocop:disable Lint/RescueException
          job_status = :failed
          transaction_set_error(transaction, exception)
          raise exception
        ensure
          if transaction
            # Present in Rails 6 and up
            transaction.set_queue_start((queue_start.to_f * 1_000).to_i) if queue_start

            unless has_wrapper_transaction
              # Only complete transaction if ActiveJob is not wrapped in
              # another supported integration, such as Sidekiq.
              Appsignal::Transaction.complete_current!
            end
          end

          metrics = ActiveJobHelpers.metrics_for(job)
          metrics.each do |(metric_name, tags)|
            if job_status
              ActiveJobHelpers.increment_counter metric_name, 1,
                tags.merge(:status => job_status)
            end
            ActiveJobHelpers.increment_counter metric_name, 1,
              tags.merge(:status => :processed)
          end

          queue_name = job["queue_name"]
          if queue_time && queue_name
            ActiveJobHelpers.add_distribution_value(
              "queue_time",
              queue_time,
              :queue => queue_name
            )
          end
        end

        private

        def transaction_set_error(transaction, exception)
          # Only report errors when the config option is set to "all".
          # To report errors on discard, see the `after_discard` callback.
          return unless Appsignal.config[:activejob_report_errors] == "all"

          transaction.set_error(exception)
        end
      end

      module ActiveJobHelpers
        ACTION_MAILER_CLASSES = [
          "ActionMailer::DeliveryJob",
          "ActionMailer::Parameterized::DeliveryJob",
          "ActionMailer::MailDeliveryJob"
        ].freeze

        def self.action_name(job)
          case job["job_class"]
          when *ACTION_MAILER_CLASSES
            job["arguments"][0..1].join("#")
          else
            "#{job["job_class"]}#perform"
          end
        end

        # Returns an array of metrics with tags used to report the job metrics
        #
        # If job ONLY has a queue, it will return `queue_job_count` with tags.
        # If job has a queue AND priority, it will ALSO return
        # `queue_priority_job_count` with tags.
        #
        # @return [Array] Array of metrics with tags to report.
        def self.metrics_for(job)
          tags = { :queue => job["queue_name"] }
          metrics = [["queue_job_count", tags]]

          priority = job["priority"]
          if priority
            metrics << [
              "queue_priority_job_count",
              tags.merge(:priority => priority)
            ]
          end

          metrics
        end

        def self.transaction_tags_for(job)
          tags = {}

          queue = job["queue_name"]
          tags[:queue] = queue if queue

          priority = job["priority"]
          tags[:priority] = priority if priority

          executions = job["executions"]
          tags[:executions] = executions.to_i + 1 if executions

          job_id = job["job_id"]
          tags[:active_job_id] = job_id

          provider_job_id = job["provider_job_id"]
          tags[:provider_job_id] = provider_job_id if provider_job_id

          request_id = provider_job_id || job_id
          tags[:request_id] = request_id if request_id

          tags
        end

        def self.increment_counter(key, value, tags = {})
          Appsignal.increment_counter "active_job_#{key}", value, tags
        end

        def self.add_distribution_value(key, value, tags = {})
          Appsignal.add_distribution_value("active_job_#{key}", value, tags)
        end
      end
    end
  end
end
