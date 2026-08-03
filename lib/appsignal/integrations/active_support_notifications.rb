# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      class << self
        BANG = "!"

        # ActiveSupport::Notifications events whose span represents an outgoing
        # call to a datastore, so they carry CLIENT kind in collector mode (to
        # match the dedicated DB integrations). Kept deliberately narrow:
        # `start_event` runs for every instrumented Rails event and span kind is
        # immutable, so only genuine client calls belong here. Object
        # instantiation (`instantiation.active_record`) is not a client call.
        #
        # `sql.sequel` is emitted by the sequel-rails gem through
        # ActiveSupport::Notifications, so it reaches us here rather than through
        # the dedicated Sequel hook (which already tags its own query events as
        # CLIENT). Including it keeps a Sequel query CLIENT regardless of which
        # path records it.
        #
        # `search.elasticsearch` is a query sent to an Elasticsearch cluster, so
        # it is a client call for the same reason a SQL query is.
        CLIENT_EVENT_NAMES = [
          "sql.active_record",
          "sql.sequel",
          "search.elasticsearch"
        ].freeze

        # Template rendering has no semantic convention to describe it, so
        # these events say which group they belong to directly. The trace
        # timeline reads `appsignal.group` before it looks at any convention
        # attribute, and "render" is the group it shows as "Templating".
        RENDER_ATTRIBUTES = { "appsignal.group" => "render" }.freeze

        # OpenTelemetry attributes to add to an event's span, by event name.
        # These name the kind of work an event represents, which is what the
        # trace timeline reads to tell one kind of span from another.
        #
        # SQL events are not listed here: their span already gets
        # `db.system.name` from the SQL body format, which also tells the
        # collector to sanitize the query.
        EVENT_ATTRIBUTES = {
          "search.elasticsearch" => {
            "db.system.name" => "elasticsearch",
            # This notification is only emitted for a search, so that is the
            # operation every one of these spans describes.
            "db.operation.name" => "search"
          }.freeze,
          "perform.active_job" =>
            Appsignal::OpenTelemetry::Messaging.perform_attributes("active_job").freeze,
          "render_template.action_view" => RENDER_ATTRIBUTES,
          "render_partial.action_view" => RENDER_ATTRIBUTES,
          "render_collection.action_view" => RENDER_ATTRIBUTES,
          "render_layout.action_view" => RENDER_ATTRIBUTES,
          "render.view_component" => RENDER_ATTRIBUTES
        }.freeze

        # Events a dedicated AppSignal integration already records with richer
        # semantics, so the generic notifications path must not record them a
        # second time. The ActiveJob hook owns `enqueue.active_job`: it wraps the
        # enqueue in a producer event that also injects trace context, and the
        # native notification fires nested inside it. The Faraday integration owns
        # `request.faraday`: its middleware records the request as a client event
        # and injects trace context, and Faraday's own instrumentation
        # notification, if the user added that middleware, fires nested inside it.
        SUPPRESSED_EVENT_NAMES = ["enqueue.active_job", "request.faraday"].freeze

        def start_event(name)
          return unless record_event?(name)

          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => CLIENT_EVENT_NAMES.include?(name.to_s) ? :client : nil,
            :opentelemetry_scope => scope_for(name)
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
          attributes = EVENT_ATTRIBUTES[name.to_s]
          transaction.add_opentelemetry_attributes(attributes) if attributes
          transaction.add_opentelemetry_attributes(payload_attributes(name, payload))
          transaction.finish_event(
            name.to_s,
            title,
            body,
            body_format
          )
        end

        # Attributes whose value has to be read from the event's payload, so they
        # cannot live in the static map above. An event with nothing to read gets
        # no attributes.
        def payload_attributes(name, payload)
          case name.to_s
          when "search.elasticsearch"
            { "db.collection.name" => search_index(payload) }.compact
          when "perform.active_job"
            { "messaging.destination.name" => job_queue_name(payload) }.compact
          else
            {}
          end
        end

        # The index a search ran against, which the notification carries in the
        # search it describes. A search that names more than one index, or none
        # at all, is left without this attribute rather than described with a
        # value that is not an index name.
        def search_index(payload)
          search = payload[:search]
          return unless search.respond_to?(:[])

          index = search[:index]
          index if index.is_a?(String)
        end

        # The queue the job being performed is on, which the notification carries
        # as the job itself.
        def job_queue_name(payload)
          job = payload[:job]
          job.queue_name if job.respond_to?(:queue_name)
        end

        # Events starting with a bang are internal to Rails; suppressed events
        # are recorded by a dedicated integration instead. Both `start_event`
        # and `finish_event` gate on this so the event stack stays balanced.
        def record_event?(name)
          name = name.to_s
          name[0] != BANG && !SUPPRESSED_EVENT_NAMES.include?(name)
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
