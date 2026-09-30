# frozen_string_literal: true

require "securerandom"

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # The resource attributes that identify the current process:
    # `service.instance.id` and `process.pid`. The OpenTelemetry providers are
    # built once, so a process forked after that inherits its parent's values
    # until {.attach_fork_hook} refreshes them in the child.
    module ProcessResource
      SERVICE_INSTANCE_ID = "service.instance.id"
      PROCESS_PID = "process.pid"
      REFRESH_FAILED = "Could not refresh the OpenTelemetry resource after fork"

      class << self
        # A random UUIDv4, generated again when the process ID changes.
        def service_instance_id
          pid = Process.pid
          unless @service_instance_id_pid == pid
            @service_instance_id = SecureRandom.uuid
            @service_instance_id_pid = pid
          end
          @service_instance_id
        end

        def resource
          ::OpenTelemetry::SDK::Resources::Resource.create(
            SERVICE_INSTANCE_ID => service_instance_id,
            PROCESS_PID => Process.pid
          )
        end

        def attach_fork_hook
          return if @fork_hook_attached

          Process.singleton_class.prepend(ForkHook)
          @fork_hook_attached = true
        end

        def before_fork
          return unless Appsignal::OpenTelemetry.started?

          providers.transform_values do |provider|
            current = current_resource(provider)
            current && attribute(current, SERVICE_INSTANCE_ID)
          end
        rescue => e
          log_failure("#{e.class}: #{e.message}")
          nil
        end

        def after_fork(instance_ids_before_fork)
          return unless instance_ids_before_fork

          update = resource
          providers.each do |name, provider|
            refresh(name, provider, update, instance_ids_before_fork[name])
          end
        rescue => e
          log_failure("#{e.class}: #{e.message}")
        end

        private

        def providers
          {
            "tracer" => ::OpenTelemetry.tracer_provider,
            "meter" => ::OpenTelemetry.meter_provider,
            "logger" => ::OpenTelemetry.logger_provider
          }
        end

        def refresh(name, provider, update, instance_id_before_fork)
          current = current_resource(provider)
          unless current
            log_failure("the #{name} provider's resource could not be read")
            return
          end
          return unless attribute(current, SERVICE_INSTANCE_ID) == instance_id_before_fork

          refreshed = current.merge(update)
          write_resource(provider, refreshed)
          return if current_resource(provider).equal?(refreshed)

          log_failure("the #{name} provider did not keep the new resource")
        end

        # The SDK providers take their resource only in their constructors, and
        # read it from `@resource` when they export.
        def current_resource(provider)
          if provider.respond_to?(:resource)
            resource = provider.resource
            unless provider.respond_to?(:resource=)
              # Without a setter, only `@resource` can be written, and it isn't there.
              return unless provider.instance_variable_defined?(:@resource)
              # The reader returns something else, so writing `@resource` would change nothing.
              return unless provider.instance_variable_get(:@resource).equal?(resource)
            end
          elsif provider.instance_variable_defined?(:@resource)
            resource = provider.instance_variable_get(:@resource)
          end
          # If it's not a resource, it isn't what the provider exports.
          resource if resource.is_a?(::OpenTelemetry::SDK::Resources::Resource)
        end

        def write_resource(provider, resource)
          if provider.respond_to?(:resource=)
            provider.resource = resource
          else
            provider.instance_variable_set(:@resource, resource)
          end
        end

        def attribute(resource, key)
          resource.attribute_enumerator.each { |k, v| return v if k == key }
          nil
        end

        def log_failure(reason)
          Appsignal.internal_logger.warn("#{REFRESH_FAILED}: #{reason}")
        end
      end

      module ForkHook
        def _fork
          instance_ids = ProcessResource.before_fork
          pid = super
          ProcessResource.after_fork(instance_ids) if pid.zero?
          pid
        end
      end
    end
  end
end
