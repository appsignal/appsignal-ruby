# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    class DelayedJobPlugin < ::Delayed::Plugin
      extend Appsignal::Hooks::Helpers

      callbacks do |lifecycle|
        lifecycle.around(:enqueue) do |job, &block|
          enqueue_with_instrumentation(job, block)
        end

        lifecycle.around(:invoke_job) do |job, &block|
          invoke_with_instrumentation(job, block)
        end

        lifecycle.after(:execute) do |_execute|
          Appsignal.stop("delayed job")
        end
      end

      # Records an `enqueue.delayed_job` event so the enqueue shows up under the
      # active transaction (e.g. when enqueuing from within a web request or
      # another job). An enqueue with no active transaction is a transparent
      # pass-through.
      def self.enqueue_with_instrumentation(job, block)
        # Skip the enqueue event when enqueue instrumentation is disabled.
        if Appsignal.config && !Appsignal.config[:enable_job_enqueue_instrumentation]
          return block.call(job)
        end

        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.job_enqueue_events_suppressed?
          return block.call(job)
        end

        Appsignal.instrument(
          "enqueue.delayed_job",
          "enqueue #{enqueue_name(job)} job",
          :opentelemetry_kind => :producer,
          :opentelemetry_scope => ["appsignal-ruby/delayed_job", Appsignal::VERSION]
        ) do
          # Describes this span as a job being enqueued. The messaging system
          # is what the trace timeline reads to recognize background job work,
          # and `delayed_job` is the value OpenTelemetry's own Delayed Job
          # instrumentation uses.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::Messaging
              .enqueue_attributes("delayed_job", :destination => queue_name(job))
          )
          block.call(job)
        end
      end

      # Titles the enqueue event after the job. The `appsignal_name` override is
      # honored verbatim, as it is when naming the perform action. That override
      # is a full action name, so an enqueue that uses it reads as
      # `enqueue Class#method job` rather than the bare `enqueue Class job`. We
      # accept that inconsistency so the enqueue and perform events stay tied to
      # the same name for the rare job that sets it.
      # The queue a job is on. Not every Delayed Job backend has queues, so a
      # job that does not know its queue is described without one.
      def self.queue_name(job)
        job.queue if job.respond_to?(:queue)
      end

      def self.enqueue_name(job)
        payload = job.payload_object
        appsignal_name = extract_value(payload, :appsignal_name, nil)
        return appsignal_name if appsignal_name.is_a?(String)

        job.name
      end

      # The trace context to continue. Delayed Job has no carrier of its own,
      # because a job's handler is a YAML dump of the object to run with nowhere
      # to put a header, so an Active Job job is the only kind that arrives with
      # one.
      def self.extract_context(job)
        Appsignal::OpenTelemetry.extract_active_job_context(active_job_data(job))
      end

      # The serialized Active Job job data inside a Delayed Job job, or nil when
      # this is not an Active Job job. The Active Job adapter wraps the job data
      # in an object that exposes it as `job_data`.
      #
      # Reading it means deserializing the handler, which raises for a job whose
      # class is gone, so a job that cannot be read gets no context. Delayed Job
      # remembers a payload it read successfully, so doing this before the job
      # runs costs no extra work later.
      def self.active_job_data(job)
        payload = job.payload_object
        payload.job_data if payload.respond_to?(:job_data)
      rescue => error
        warn_unreadable_payload_once(error)
        nil
      end

      def self.invoke_with_instrumentation(job, block)
        transaction =
          Appsignal::Transaction.create(
            Appsignal::Transaction::BACKGROUND_JOB,
            :opentelemetry_context => extract_context(job),
            :opentelemetry_scope => ["appsignal-ruby/delayed_job", Appsignal::VERSION],
            :opentelemetry_kind => :consumer,
            :opentelemetry_relationship => :both
          )
        transaction.add_opentelemetry_attributes(
          Appsignal::OpenTelemetry::Messaging
            .perform_attributes("delayed_job", :destination => queue_name(job))
        )

        begin
          Appsignal.instrument(
            "perform_job.delayed_job",
            :opentelemetry_scope => ["appsignal-ruby/delayed_job", Appsignal::VERSION]
          ) do
            Appsignal::Transaction.current.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::Messaging
                .perform_attributes("delayed_job", :destination => queue_name(job))
            )
            block.call(job)
          end
        rescue Exception => error
          transaction.set_error(error)
          raise
        ensure
          # Delayed Job raises when a job's handler will not deserialize, and it
          # raises again on every further attempt to read it. Reading the payload
          # here without a guard therefore replaces the error the job already
          # failed with, and skips the rest of this block, so the transaction is
          # never completed and the failure is never reported.
          begin
            payload = job.payload_object
            if payload.respond_to? :job_data
              # ActiveJob
              job_data = payload.job_data
              transaction.set_action_if_nil("#{job_data["job_class"]}#perform")
              transaction.add_function_parameters_if_nil(job_data.fetch("arguments", {}))
            else
              # Delayed Job
              transaction.set_action_if_nil(action_name_from_payload(payload, job.name))
              transaction.add_function_parameters_if_nil(extract_value(payload, :args, {}))
            end
          rescue => error
            warn_unreadable_payload_once(error)
            transaction.set_action_if_nil(action_name_without_payload(job))
          end

          transaction.add_tags(
            :id => extract_value(job, :id, nil, true),
            :queue => extract_value(job, :queue),
            :priority => extract_value(job, :priority, 0),
            :attempts => extract_value(job, :attempts, 0)
          )

          transaction.set_queue_start(extract_value(job, :run_at)&.to_i&.* 1_000)

          Appsignal::Transaction.complete_current!
        end
      end

      # The name Delayed Job derives from the raw handler when the payload will
      # not deserialize. It reads the class name out of the handler with a
      # regular expression, which covers the job class a deploy removed. That
      # expression raises for a handler it does not match, and it is skipped
      # altogether when the payload raised something Delayed Job does not wrap,
      # so name Delayed Job itself when there is nothing else to go on. The
      # failure is then reported under a name that can be found, and every job
      # this happens to is grouped together.
      def self.action_name_without_payload(job)
        with_perform_suffix(job.name)
      rescue
        "Delayed::Job#perform"
      end

      # Guards the check-and-set below, so two threads that read an unreadable
      # payload at the same time cannot both warn. A constant so it is created
      # once at load time, because creating it lazily would race in turn.
      WARN_ONCE_LOCK = Mutex.new

      # A deploy that removes a job class leaves every job of that class unable
      # to deserialize, so this can be reached once per job. Each of those jobs
      # reports its own error to AppSignal, so the log only has to say once that
      # it is happening.
      def self.warn_unreadable_payload_once(error)
        should_warn = WARN_ONCE_LOCK.synchronize do
          next false if @warned_unreadable_payload

          @warned_unreadable_payload = true
        end
        return unless should_warn

        Appsignal.internal_logger.warn(
          "Unable to read a Delayed Job job's payload: #{error.class}: " \
            "#{error.message}. Jobs whose payload cannot be read are reported " \
            "without parameters. They are named after the class in their raw " \
            "handler, or after Delayed::Job#perform when that cannot be read " \
            "either."
        )
      end

      # @!visibility private
      #
      # Resets the warn-once state. Only used to keep test runs isolated.
      def self.reset_unreadable_payload_warning!
        WARN_ONCE_LOCK.synchronize { @warned_unreadable_payload = false }
      end

      def self.action_name_from_payload(payload, default_name)
        # Attempt to find appsignal_name override
        class_and_method_name = extract_value(payload, :appsignal_name, nil)
        return class_and_method_name if class_and_method_name.is_a?(String)

        with_perform_suffix(default_name)
      end

      # An action name is a class and a method. A name that already names both,
      # separated either way, is left alone.
      def self.with_perform_suffix(name)
        return name if name.split("#").length == 2
        return name if name.split(".").length == 2

        "#{name}#perform"
      end

      # rubocop:disable Style/OptionalBooleanParameter
      def self.extract_value(object_or_hash, field, default_value = nil, convert_to_s = false)
        value = nil

        # Attempt to read value from hash
        if object_or_hash.respond_to?(:[])
          value = begin
            object_or_hash[field]
          rescue NameError
            nil
          end
        end

        # Attempt to read value from object
        value = object_or_hash.send(field) if value.nil? && object_or_hash.respond_to?(field)

        # Set default value if nothing was found
        value = default_value if value.nil?

        if convert_to_s
          value.to_s
        else
          value
        end
      end
      # rubocop:enable Style/OptionalBooleanParameter
    end
  end
end
