# frozen_string_literal: true

require "json"

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The transaction backend used in collector mode. Emits an OpenTelemetry
    # root span for the transaction lifecycle plus child spans for each
    # instrumented event. Error events land in a subsequent step.
    #
    # On construction the backend starts an OTel root span and attaches it
    # to the current OpenTelemetry context, so any third-party OTel
    # instrumentation that runs while the transaction is active nests
    # naturally under the transaction's span. `start_event` opens a child
    # span and pushes it onto a per-transaction LIFO; `finish_event` pops
    # it, renames it from a placeholder to the event name, writes the
    # body/title attributes, and closes the span. `record_event` is the
    # post-facto variant that creates a span with a backdated start
    # timestamp. On `complete` the backend drains any leftover event
    # spans, detaches the root context, and finishes the root span.
    class OpenTelemetryBackend
      TRACER_NAME = "appsignal-ruby"

      # Keys correspond to `Appsignal::Transaction::HTTP_REQUEST`,
      # `ACTION_CABLE` and `BACKGROUND_JOB` respectively. Spelled as strings
      # because this file is required (via `Backends`) before
      # `lib/appsignal/transaction.rb`, so the constants are not yet defined
      # at class-body evaluation time.
      SPAN_KIND_BY_NAMESPACE = {
        "http_request" => :server,
        "action_cable" => :server,
        "background_job" => :consumer
      }.freeze

      # Collector treats SERVER/CONSUMER spans as subtrace roots; SERVER is
      # the safe default for user-defined namespaces (almost always
      # external-triggered units of work).
      DEFAULT_SPAN_KIND = :server

      # Placeholder name an event span carries between `start_event` and
      # `finish_event`. `finish_event` overwrites it with the AS::N event
      # name; only surfaces if `complete` has to drain a span that was
      # started but never finished.
      EVENT_SPAN_PLACEHOLDER_NAME = "appsignal.event"

      # Sentinel value the AppSignal collector recognizes as "a SQL system
      # we don't know the specific dialect of" — sufficient to trigger SQL
      # sanitization on `db.query.text`.
      SQL_DB_SYSTEM = "other_sql"

      def initialize(transaction_id, namespace, **)
        @transaction_id = transaction_id
        @namespace = namespace
        @completed = false
        @event_stack = []
        @breadcrumb_count = 0

        # `start_root_span` (not `start_span`) so the transaction's root
        # ignores any ambient OTel context. A transaction is a unit of work
        # in its own right -- nesting it under whatever span happens to be
        # current would lose that boundary and mix unrelated traces.
        @span = tracer.start_root_span(
          placeholder_span_name(namespace),
          :kind => SPAN_KIND_BY_NAMESPACE.fetch(namespace, DEFAULT_SPAN_KIND)
        )
        @context_token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(@span)
        )

        # `Appsignal::Transaction#initialize` sets `@namespace` directly and
        # never calls `set_namespace`, so emit the attribute here from the
        # constructor namespace -- otherwise a transaction that never calls
        # `set_namespace` would carry no namespace for the collector.
        @span.set_attribute("appsignal.namespace", namespace) if namespace
      end

      def start_event
        span = tracer.start_span(EVENT_SPAN_PLACEHOLDER_NAME)
        token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(span)
        )
        @event_stack.push([span, token])
      end

      def finish_event(name, title, body, body_format)
        return if @event_stack.empty?

        span, token = @event_stack.pop
        write_event_name_attributes(span, name, title)
        write_event_body_attributes(span, body, body_format)
        ::OpenTelemetry::Context.detach(token)
        span.finish
      end

      def record_event(name, title, body, body_format, duration)
        start_time = Time.now - (duration / 1_000_000_000.0)
        span = tracer.start_span(EVENT_SPAN_PLACEHOLDER_NAME, :start_timestamp => start_time)
        write_event_name_attributes(span, name, title)
        write_event_body_attributes(span, body, body_format)
        span.finish
      end

      def set_action(action) # rubocop:disable Naming/AccessorMethodName
        # The collector reads the action from `appsignal.action_name`, not the
        # span name. Set the name too so the OTel-native trace stays readable;
        # the collector treats the span name as authoritative for display.
        @span.name = action
        @span.set_attribute("appsignal.action_name", action)
      end

      def set_namespace(namespace) # rubocop:disable Naming/AccessorMethodName
        # Only the attribute can change here: SpanKind is fixed at span
        # creation (immutable in OTel) from the initial namespace. A later
        # namespace override updates `appsignal.namespace` but not the kind --
        # the collector uses the attribute for the namespace and the kind only
        # to pick the subtrace root, so this is fine for the rare late change.
        @namespace = namespace
        @span.set_attribute("appsignal.namespace", namespace)
      end

      # Intentional no-op. Nothing in the OpenTelemetry pipeline consumes a queue
      # start: the agent only uses it to compute a `queue_duration` scalar (it
      # does not backdate the transaction), the collector has no handling, and
      # the spans processor reports `queue_duration: 0` for OTel traces. A bare
      # timestamp is meaningless without a consumer to compute the delta, and
      # emulating it via span timing would distort the trace duration, so we drop
      # it rather than emit an attribute nothing reads.
      def set_queue_start(_start) # rubocop:disable Naming/AccessorMethodName
      end

      # Transaction metadata (request path, method, ...) has no dedicated OTel
      # attribute, but it is the same shape as tags and the collector/trace UI
      # already surface `appsignal.tag.*`, so emit metadata as a tag.
      def set_metadata(key, value)
        @span.set_attribute("appsignal.tag.#{key}", value)
      end

      # Routes each sample-data category to the attribute the collector and the
      # server's trace UI recognize. The JSON-blob categories (params, session
      # data, custom data) are serialized as JSON strings; the collector
      # re-parses and filters them. `environment` is handled in a later branch.
      # `error_causes` and `breadcrumbs` are intentionally dropped here: causes
      # ride on the exception event (see #set_error) and breadcrumbs are emitted
      # per-call as span events on the current span (see #add_breadcrumb), so
      # flushing either as sample data would duplicate them on the root span. Any
      # other (unknown) category is passed through as a JSON `appsignal.<key>`
      # attribute so no data is lost.
      def set_sample_data(key, data)
        case key
        when "params"
          @span.set_attribute(params_attribute, JSON.generate(data))
        when "session_data"
          @span.set_attribute("appsignal.request.session_data", JSON.generate(data))
        when "custom_data"
          @span.set_attribute("appsignal.custom_data", JSON.generate(data))
        when "environment"
          write_request_headers(data)
        when "breadcrumbs"
          # No-op: breadcrumbs are emitted as `appsignal.breadcrumb` span events
          # on the current span at add time (see #add_breadcrumb). Flushing them
          # here would re-emit them on the already-finished root span.
        when "tags"
          write_tags(data)
        when "error_causes"
          # No-op: causes are emitted as the exception event's
          # `appsignal.error_causes` attribute (see #set_error), not sample data.
        else
          @span.set_attribute("appsignal.#{key}", JSON.generate(data))
        end
      end

      # Records the error as an OpenTelemetry `exception` span-event on the
      # span that is current *now* -- which may be an event span, not the root --
      # so the error attaches to the operation that raised it. The Transaction
      # records each error at the moment it is added, so the current span is the
      # one active at that point.
      #
      # `appsignal.alert_this_error` makes the collector report the exception
      # even when it is on a non-root span: the collector reports every exception
      # on the root span, but only flagged ones on child spans. The collector
      # computes `appsignal.error_digest` itself, so we don't set it here.
      #
      # Causes are emitted as a single `appsignal.error_causes` JSON attribute on
      # the exception event (not on the span): separate cause events would each
      # be stamped with a digest and become their own incident. The processor
      # reads `appsignal.error_causes` off the event and expands it into cause
      # subdata. The JSON keys (`name`/`message`/`lines`) match the processor's
      # `ErrorSubCause` struct.
      def set_error(class_name, message, backtrace, causes)
        span = ::OpenTelemetry::Trace.current_span

        attributes = {
          "exception.type" => class_name,
          "exception.message" => message.to_s,
          "exception.stacktrace" => Array(backtrace).join("\n"),
          "appsignal.alert_this_error" => true
        }

        unless causes.empty?
          attributes["appsignal.error_causes"] = JSON.generate(
            causes.map do |cause|
              {
                "name" => cause[:name],
                "message" => cause[:message],
                "lines" => cause[:lines] || []
              }
            end
          )
        end

        span.add_event("exception", :attributes => attributes)
        span.status = ::OpenTelemetry::Trace::Status.error
      end

      # Emits a breadcrumb as an `appsignal.breadcrumb` span event on the span
      # that is current *now* -- the event span active when the breadcrumb was
      # added, falling back to the root span when none is open. Breadcrumbs are
      # emitted immediately (not flushed at completion) because by completion the
      # event span has finished, and the OTel SDK drops events added to an ended
      # span.
      #
      # The breadcrumb's recorded time becomes the event timestamp (events carry
      # their own time), so it is not duplicated as an attribute;
      # category/action/message are attributes and the metadata Hash is a JSON
      # string (event attributes are flat).
      #
      # Capped at `BREADCRUMB_LIMIT` per transaction: streamed events can't be
      # retracted, so we keep the first N rather than agent mode's last N.
      def add_breadcrumb(breadcrumb)
        return if @breadcrumb_count >= Appsignal::Transaction::BREADCRUMB_LIMIT

        @breadcrumb_count += 1
        ::OpenTelemetry::Trace.current_span.add_event(
          "appsignal.breadcrumb",
          :timestamp => Time.at(breadcrumb[:time]),
          :attributes => {
            "category" => breadcrumb[:category],
            "action" => breadcrumb[:action],
            "message" => breadcrumb[:message],
            "metadata" => JSON.generate(breadcrumb[:metadata] || {})
          }
        )
      end

      # Returns `true` so `Transaction#complete` runs `sample_data`, flushing the
      # params/session/custom-data/tags/etc. onto the still-open root span before
      # `complete` finishes it. The OTel SDK makes its own sampling decision; the
      # gem always populates the span.
      def finish
        true
      end

      def complete
        teardown
      end

      # Discarding does not mean "don't send" as it does in agent mode: the
      # root span is still finished and exported, but flagged with
      # `appsignal.ignore_subtrace = true` so the collector drops the whole
      # subtrace (the attribute is hoisted to the subtrace root, last write
      # wins). The flag must be written before the span finishes -- attributes
      # set on an ended span are dropped. Tearing the span down here also
      # detaches the context, so a discarded transaction can't leak its root
      # span as the current OTel context onto the thread.
      def discard
        return if @completed

        @span&.set_attribute("appsignal.ignore_subtrace", true)
        teardown
      end

      def duplicate(new_transaction_id)
        self.class.new(new_transaction_id, @namespace)
      end

      # Multiple errors are recorded as multiple `exception` events on the one
      # root span (each its own incident), so the Transaction does not need to
      # duplicate itself per error.
      def supports_multiple_errors?
        true
      end

      # Returned so `Transaction#to_h` (which does `JSON.parse(@backend.to_json)`)
      # produces an empty Hash instead of raising. The existing agent-mode
      # transaction matchers all read from `to_h`; in collector mode they
      # will be replaced by OTel-based assertions in subsequent steps.
      def to_json # rubocop:disable Lint/ToJSON
        "{}"
      end

      # Test-mode introspection parity with `ExtensionBackend`. Returns `nil`
      # for now since `set_queue_start` is a no-op; `_completed?` toggles on
      # `complete` so `be_completed` keeps working.
      def queue_start
        nil
      end

      def _completed?
        @completed
      end

      private

      # Detaches the OTel context and finishes the root span. Shared by
      # `complete` and `discard`.
      #
      # Idempotent: tearing down twice would re-detach an already-detached
      # context (a mismatched-detach error) and re-finish an ended span (a
      # warning). The Transaction can be completed directly and then again by a
      # `complete_current!` cleanup path, so guard against it.
      def teardown
        return if @completed

        @completed = true
        # Drain unfinished event spans defensively: if `start_event` was
        # called without a matching `finish_event` (caller bug or aborted
        # flow), the root context can't detach in LIFO order until the
        # event tokens are released first.
        until @event_stack.empty?
          span, token = @event_stack.pop
          ::OpenTelemetry::Context.detach(token)
          span.finish
        end
        ::OpenTelemetry::Context.detach(@context_token) if @context_token
        @span&.finish
      end

      def tracer
        ::OpenTelemetry.tracer_provider.tracer(TRACER_NAME, Appsignal::VERSION)
      end

      def placeholder_span_name(namespace)
        "appsignal.transaction #{namespace}"
      end

      # The collector exposes three params channels (query parameters, request
      # payload, function parameters), each separately filtered and labeled in
      # the trace UI. The gem only has a single merged params blob, so route it
      # by namespace: message/job (CONSUMER-kind) transactions use the
      # function-parameters channel, everything else (web-style, SERVER-kind)
      # uses the request-payload channel.
      def params_attribute
        if SPAN_KIND_BY_NAMESPACE.fetch(@namespace, DEFAULT_SPAN_KIND) == :consumer
          "appsignal.function.parameters"
        else
          "appsignal.request.payload"
        end
      end

      # The transaction's "environment" sample data is a Rack/CGI env allowlist
      # mixing true HTTP headers (HTTP_*, plus CONTENT_LENGTH/CONTENT_TYPE) with
      # non-header CGI vars (REQUEST_METHOD, REQUEST_PATH, PATH_INFO, SERVER_*).
      # Only the true headers map to the OTel `http.request.header.*` convention
      # the collector and trace UI read, so emit those (normalized to lowercase,
      # dashed header names) and drop everything else.
      def write_request_headers(headers)
        headers.each do |key, value|
          name = otel_header_name(key)
          @span.set_attribute("http.request.header.#{name}", value.to_s) if name
        end
      end

      def otel_header_name(env_key)
        if env_key.start_with?("HTTP_")
          env_key.delete_prefix("HTTP_").downcase.tr("_", "-")
        elsif env_key.start_with?("CONTENT_")
          env_key.downcase.tr("_", "-")
        end
      end

      # Each tag becomes its own `appsignal.tag.<key>` attribute, which the
      # collector hoists and the trace UI lists under "Tags". `sanitized_tags`
      # already restricts values to String/Symbol/Integer/boolean; OTel
      # attribute values must be primitives, so coerce the Symbol case to a
      # string (the only non-primitive that survives sanitization).
      def write_tags(tags)
        tags.each do |key, value|
          value = value.to_s if value.is_a?(Symbol)
          @span.set_attribute("appsignal.tag.#{key}", value)
        end
      end

      # The OTel span name is what the collector surfaces as the event's
      # label in the trace UI, so prefer the human-readable `title` (e.g.
      # "User Load", "GET https://example.com") and fall back to the AS::N
      # `name` (e.g. "sql.active_record") when no formatter supplied a title.
      # The machine name still rides along in `appsignal.category` so it is
      # not lost once the title wins the span name -- it keeps the event's
      # grouping key available for later filtering.
      def write_event_name_attributes(span, name, title)
        span.name = title && !title.empty? ? title : name
        span.set_attribute("appsignal.category", name)
      end

      def write_event_body_attributes(span, body, body_format)
        return if body.nil? || body.empty?

        if body_format == Appsignal::EventFormatter::SQL_BODY_FORMAT
          span.set_attribute("db.query.text", body)
          span.set_attribute("db.system.name", SQL_DB_SYSTEM)
        else
          span.set_attribute("appsignal.body", body)
        end
      end
    end
  end
end
