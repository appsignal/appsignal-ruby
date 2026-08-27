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
        self.class.dependencies_present? && Appsignal.config &&
          Appsignal.config[:instrument_active_job]
      end

      def install
        ActiveSupport.on_load(:active_job) do
          ::ActiveJob::Base
            .extend ::Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation
          ::ActiveJob::Base
            .prepend ::Appsignal::Hooks::ActiveJobHook::ActiveJobEnqueueInstrumentation

          # Active Job records a bulk enqueue through this method, which only
          # exists from version 7.1 on. Checking for the method, rather than for
          # the version, keeps us from defining one on a version that has no
          # bulk enqueue path to instrument.
          if ::ActiveJob.singleton_class.private_method_defined?(:instrument_enqueue_all)
            ::ActiveJob.singleton_class
              .prepend ::Appsignal::Hooks::ActiveJobHook::ActiveJobBulkEnqueueInstrumentation
          else
            # Without that method there is no way to record the batch ourselves,
            # so let Rails' own notification through instead. Claiming the event
            # and then not recording it would report nothing at all, which is
            # worse than reporting the notification we were trying to improve on.
            require "appsignal/integrations/active_support_notifications"
            Appsignal::Integrations::ActiveSupportNotificationsIntegration
              .unsuppress_event("enqueue_all.active_job")
          end

          next unless Appsignal::Hooks::ActiveJobHook.version_7_1_or_higher?

          # Only works on Active Job 7.1 and newer
          ::ActiveJob::Base.after_discard do |_job, exception|
            next unless Appsignal.config[:activejob_report_errors] == "discard"

            Appsignal::Transaction.current.set_error(exception)
          end
        end
      end

      # Records an `enqueue.active_job` event when a job is enqueued, so the
      # enqueue shows up on the active transaction's timeline (e.g. when
      # enqueuing from within a web request or another job).
      #
      # Wrapping `enqueue` ourselves -- rather than relying on Rails' native
      # `enqueue.active_job` notification, which the AppSignal notifications
      # path now suppresses -- gives us a single event we own. Like all
      # AppSignal events, this only records when there's an active transaction;
      # an enqueue with no transaction is a transparent pass-through.
      #
      # @!visibility private
      module ActiveJobEnqueueInstrumentation
        def enqueue(*, **)
          # Skip recording the event when enqueue events are suppressed. That is
          # the case when enqueue instrumentation is disabled, and it keeps this
          # integration consistent with the standalone adapters (Sidekiq, ...),
          # which already gate their own enqueue event on this check.
          if Appsignal::Transaction.current? &&
              Appsignal::Transaction.current.job_enqueue_events_suppressed?
            return super
          end

          Appsignal.instrument("enqueue.active_job", "enqueue #{self.class.name} job") do
            # Active Job enqueues through an adapter (Sidekiq, Resque, ...) that
            # has its own enqueue instrumentation. Suppress it so the enqueue is
            # recorded once, as this event, rather than as nested Active Job +
            # adapter events.
            if Appsignal::Transaction.current?
              Appsignal::Transaction.current.suppress_job_enqueue_events { super }
            else
              super
            end
          end
        end
      end

      # Records an `enqueue_all.active_job` event when a batch of jobs is
      # enqueued with `ActiveJob.perform_all_later`, so the batch shows up on the
      # active transaction's timeline as one event.
      #
      # This wraps `instrument_enqueue_all` rather than `perform_all_later`, for
      # two reasons. It is the method that records the batch, so it is called
      # once for each queue adapter the batch spans, which is the same event
      # count as the native notification it replaces. And it runs inside
      # `perform_all_later`, after Active Job has split off the jobs it defers
      # until the database transaction commits, so each of those halves is
      # recorded when it is really enqueued.
      #
      # @!visibility private
      module ActiveJobBulkEnqueueInstrumentation
        private

        def instrument_enqueue_all(_queue_adapter, jobs)
          # Skip recording the event when enqueue events are suppressed, which is
          # also the case when enqueue instrumentation is disabled. Same check as
          # the single-job path above.
          if Appsignal::Transaction.current? &&
              Appsignal::Transaction.current.job_enqueue_events_suppressed?
            return super
          end

          Appsignal.instrument("enqueue_all.active_job", bulk_enqueue_title(jobs)) do
            # A bulk enqueue does not go through `ActiveJob::Base#enqueue`, so
            # nothing has suppressed the adapter (Sidekiq, Resque, ...) yet, and
            # its own enqueue instrumentation would record an event for every job
            # in the batch. Suppress it so the batch is recorded once, as this
            # event.
            if Appsignal::Transaction.current?
              Appsignal::Transaction.current.suppress_job_enqueue_events { super }
            else
              super
            end
          end
        end

        # The batch's job class, when every job in it has the same one. Active
        # Job groups the jobs it enqueues by queue adapter rather than by class,
        # so a batch can mix classes, and then there is no one class to name.
        def bulk_enqueue_title(jobs)
          job_class = shared_across(jobs) { |job| job.class.name }
          return "bulk enqueue jobs" unless job_class

          "bulk enqueue #{job_class} jobs"
        end

        # The one value every job in the batch shares, or nil when they differ
        # or the batch is empty. Stops at the first job that disagrees, because
        # a batch is as large as the caller made it and a single mismatch is
        # enough to know.
        def shared_across(jobs)
          return if jobs.empty?

          first = yield(jobs.first)
          jobs.all? { |job| yield(job) == first } ? first : nil
        end
      end

      module ActiveJobClassInstrumentation
        def execute(job)
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

          begin
            transaction.add_params_if_nil(job["arguments"])

            transaction_tags = ActiveJobHelpers.transaction_tags_for(job)
            transaction.add_tags(transaction_tags)

            transaction.set_action(ActiveJobHelpers.action_name(job))

            super
          rescue Exception => exception
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
