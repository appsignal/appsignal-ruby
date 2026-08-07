# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      class << self
        BANG = "!"

        def start_event(name)
          return unless record_event?(name)

          # The event's formatter says what kind of work the event is, such as
          # a SQL query being an outgoing call to a database, and can name the
          # library the instrumentation is for. Both are immutable once the
          # span exists, so they have to be set here at event start.
          #
          # A formatter that names no library leaves the scope to be derived
          # from the event name, which is right for everything Rails reports.
          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => Appsignal::EventFormatter.opentelemetry_kind(name),
            :opentelemetry_scope =>
              Appsignal::EventFormatter.opentelemetry_scope(name) || scope_for(name)
          )
        end

        # ActiveSupport::Notifications bridges many Rails components through this
        # one path (`sql.active_record`, `render_template.action_view`, ...), so
        # derive the instrumentation scope from the event name's group: the part
        # after the last dot. That gives each Rails component its own scope
        # (`appsignal-ruby/active_record`, `appsignal-ruby/action_view`, ...)
        # rather than lumping them under one. A name without a group falls back
        # to the default scope in the backend.
        def scope_for(name)
          # Only names with a group (a dot) map to a component scope. A name
          # without one has no component to attribute it to, so it falls back to
          # the default scope in the backend (returning nil here).
          parts = name.to_s.split(".")
          return if parts.length < 2 || parts.last.empty?

          ["appsignal-ruby/#{parts.last}", Appsignal::VERSION]
        end

        def finish_event(name, payload = {})
          return unless record_event?(name)

          title, body, body_format = Appsignal::EventFormatter.format(name, payload)
          transaction = Appsignal::Transaction.current
          # Set while the event's span is still open, so the attributes land on
          # the event rather than on the transaction.
          transaction.add_opentelemetry_attributes(
            Appsignal::EventFormatter.opentelemetry_attributes(name, payload)
          )
          record_error_type(transaction, payload)
          transaction.finish_event(
            name.to_s,
            title,
            body,
            body_format
          )
        end

        # Says what kind of failure ended the event, which the OpenTelemetry
        # semantic conventions ask for on a span whose operation failed.
        #
        # ActiveSupport puts the exception in the payload when the instrumented
        # block raised, and it does so before it hands control to any of the
        # paths this integration hooks into. So the failure is readable here and
        # there is nothing to rescue, whether the event was reported through a
        # block or through a `start` and `finish` pair.
        def record_error_type(transaction, payload)
          error = payload[:exception_object]
          return unless error

          transaction.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::ErrorType.attributes_for(error.class.name)
          )
        end

        # Events starting with a bang are internal to Rails. An event that the
        # registry says a dedicated integration records is not recorded again
        # here. Both `start_event` and `finish_event` gate on this so the event
        # stack stays balanced.
        def record_event?(name)
          name.to_s[0] != BANG && Appsignal::EventFormatter.record?(name)
        end
      end

      module InstrumentIntegration
        def instrument(name, payload = {}, &block)
          ActiveSupportNotificationsIntegration.start_event(name)
          super
        ensure
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
        end
      end

      module StartFinishIntegration
        def start(name, payload = {})
          ActiveSupportNotificationsIntegration.start_event(name)
          super
        end

        def finish(name, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end

      module StartFinishHandlerIntegration
        def start
          ActiveSupportNotificationsIntegration.start_event(@name)
          super
        end

        def finish_with_values(name, id, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end

      class NullHandleIntegration
        def initialize(name, _id, payload)
          @name = name
          @payload = payload
        end

        def start
          ActiveSupportNotificationsIntegration.start_event(@name)
        end

        def finish
          finish_with_values(@name, nil, @payload)
        end

        def finish_with_values(name, _id, payload)
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
        end
      end

      module BuildHandleFanoutIntegration
        def build_handle(name, id, payload)
          handle = super

          if handle == ::ActiveSupport::Notifications::Fanout::NullHandle
            NullHandleIntegration.new(name, id, payload)
          else
            handle
          end
        end
      end

      module FinishStateIntegration
        def finish_with_state(listeners_state, name, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end
    end
  end
end
