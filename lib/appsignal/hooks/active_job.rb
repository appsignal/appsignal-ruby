# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ActiveJobHook < Appsignal::Hooks::Hook
      register :active_job

      def dependencies_present?
        defined?(::ActiveJob)
      end

      def install
        ActiveSupport.on_load(:active_job) do
          ::ActiveJob::Base
            .extend ::Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation
        end
      end

      module ActiveJobClassInstrumentation
        def execute(job)
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
              Appsignal::Transaction.create(
                job["provider_job_id"] || job["job_id"],
                Appsignal::Transaction::BACKGROUND_JOB,
                Appsignal::Transaction::GenericRequest.new({})
              )
            end

          if transaction
            transaction.params =
              Appsignal::Utils::HashSanitizer.sanitize(
                job["arguments"],
                Appsignal.config[:filter_parameters]
              )

            transaction_tags = ActiveJobHelpers.transaction_tags_for(job)
            transaction_tags["active_job_id"] = job["job_id"]
            provider_job_id = job["provider_job_id"]
            transaction_tags[:provider_job_id] = provider_job_id if provider_job_id
            transaction.set_tags(transaction_tags)

            transaction.set_action(ActiveJobHelpers.action_name(job))
          end

          super
        rescue Exception => exception # rubocop:disable Lint/RescueException
          job_status = :failed
          transaction.set_error(exception)
          raise exception
        ensure
          if transaction
            enqueued_at = job["enqueued_at"]
            if enqueued_at # Present in Rails 6 and up
              transaction.set_queue_start((Time.parse(enqueued_at).to_f * 1_000).to_i)
            end

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
          tags
        end

        def self.increment_counter(key, value, tags = {})
          Appsignal.increment_counter "active_job_#{key}", value, tags
        end
      end
    end
  end
end
