# frozen_string_literal: true

module Appsignal
  class Hooks
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
        payload = job.payload_object

        if payload.respond_to? :job_data
          # ActiveJob
          job_data = payload.job_data
          args = job_data.fetch("arguments", {})
          class_name = job_data["job_class"]
          method_name = "perform"
        else
          # Delayed Job
          args = extract_value(payload, :args, {})
          class_name, method_name = class_and_method_name_from_object_or_hash(payload, job.name)
        end

        params = Appsignal::Utils::HashSanitizer.sanitize(
          args,
          Appsignal.config[:filter_parameters]
        )

        Appsignal.monitor_transaction(
          "perform_job.delayed_job",
          :class    => class_name,
          :method   => method_name,
          :metadata => {
            :id => extract_value(job, :id, nil, true),
            :queue => extract_value(job, :queue),
            :priority => extract_value(job, :priority, 0),
            :attempts => extract_value(job, :attempts, 0)
          },
          :params      => params,
          :queue_start => extract_value(job, :run_at)
        ) do
          block.call(job)
        end
      end

      def self.class_and_method_name_from_object_or_hash(payload, default_name)
        # Attempt to find appsignal_name override
        class_and_method_name = extract_value(payload, :appsignal_name, nil)
        return class_and_method_name.split("#") if class_and_method_name.is_a?(String)

        pound_split = default_name.split("#")
        return pound_split if pound_split.length == 2

        dot_split = default_name.split(".")
        return default_name if dot_split.length == 2

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
