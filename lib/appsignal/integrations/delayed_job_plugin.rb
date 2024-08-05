# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    class DelayedJobPlugin < ::Delayed::Plugin
      extend Appsignal::Hooks::Helpers

      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, &block|
          invoke_with_instrumentation(job, block)
        end

        lifecycle.after(:execute) do |_execute|
          Appsignal.stop("delayed job")
        end
      end

      def self.invoke_with_instrumentation(job, block)
        transaction =
          Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)

        Appsignal.instrument("perform_job.delayed_job") do
          block.call(job)
        end
      rescue Exception => error # rubocop:disable Lint/RescueException
        transaction.set_error(error)
        raise
      ensure
        payload = job.payload_object
        if payload.respond_to? :job_data
          # ActiveJob
          job_data = payload.job_data
          transaction.set_action_if_nil("#{job_data["job_class"]}#perform")
          transaction.add_params_if_nil(job_data.fetch("arguments", {}))
        else
          # Delayed Job
          transaction.set_action_if_nil(action_name_from_payload(payload, job.name))
          transaction.add_params_if_nil(extract_value(payload, :args, {}))
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

      def self.action_name_from_payload(payload, default_name)
        # Attempt to find appsignal_name override
        class_and_method_name = extract_value(payload, :appsignal_name, nil)
        return class_and_method_name if class_and_method_name.is_a?(String)
        return default_name if default_name.split("#").length == 2
        return default_name if default_name.split(".").length == 2

        "#{default_name}#perform"
      end

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
    end
  end
end
