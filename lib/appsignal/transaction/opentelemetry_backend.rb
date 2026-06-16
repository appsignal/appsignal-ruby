# frozen_string_literal: true

require "json"
require "socket"

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The transaction backend used in collector mode. Emits an OpenTelemetry
    # root span for the transaction, a child span per instrumented event, and
    # queue timing as a metric. Errors and breadcrumbs attach to whichever span
    # is current when they happen.
    class OpenTelemetryBackend < BaseBackend
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

      # Epoch-ms floor (~year 2000) below which a queue start is ignored. Mirrors
      # the agent's `set_queue_start` (ext `transaction.rs`), which only records a
      # queue duration when `queue_start_ms > 946_681_200_000`.
      QUEUE_START_MIN = 946_681_200_000

      def initialize(transaction_id, namespace, **)
        super()
        @transaction_id = transaction_id
        @namespace = namespace
        @completed = false
        @event_stack = []
        @breadcrumb_count = 0
        @queue_start = nil
        @start_time = Time.now

        # A transaction is its own unit of work, so start a root span that
        # ignores any ambient OTel context instead of nesting under an
        # unrelated current span.
        @span = tracer.start_root_span(
          placeholder_span_name(namespace),
          :kind => SPAN_KIND_BY_NAMESPACE.fetch(namespace, DEFAULT_SPAN_KIND)
        )
        @context_token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(@span)
        )

        # Transaction#initialize sets the namespace directly without calling
        # set_namespace, so emit the attribute from here.
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

      # Queue start has no OTel-native home, so surface it two ways: an
      # `appsignal.queue_start` event on the root span (per-trace timeline) and,
      # at completion, a `transaction_queue_duration` metric (the aggregate
      # graph). Like the agent, we record the delta and never shift span timing.
      def set_queue_start(start) # rubocop:disable Naming/AccessorMethodName
        return unless start && start > QUEUE_START_MIN

        @queue_start = start
        @span.add_event(
          "appsignal.queue_start",
          :timestamp => Time.at(start / 1000.0),
          :attributes => { "appsignal.queue_start" => start }
        )
      end

      # Transaction metadata (request path, method, ...) has no dedicated OTel
      # attribute, but it is the same shape as tags and the collector/trace UI
      # already surface `appsignal.tag.*`, so emit metadata as a tag.
      def set_metadata(key, value)
        @span.set_attribute("appsignal.tag.#{key}", value)
      end

      # Routes each sample-data category to the attribute the collector reads.
      # The JSON-blob categories (params, session, custom data) are serialized as
      # JSON; `environment` becomes request-header attributes; tags fan out to
      # `appsignal.tag.*`. Unknown keys pass through as `appsignal.<key>` JSON so
      # nothing is lost. Breadcrumbs never reach here (the backend emits them as
      # span events); causes ride on the exception event (see #set_error).
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
        when "tags"
          write_tags(data)
        else
          @span.set_attribute("appsignal.#{key}", JSON.generate(data))
        end
      end

      # Records the error as an `exception` event on AppSignal's current span --
      # the open event span, or the root -- so it attaches to the operation that
      # raised it. Uses AppSignal's own span, not the OTel current span, which
      # may belong to another instrumentation. `appsignal.alert_this_error` tells
      # the collector to report it even on a child span; the collector computes
      # the digest. Causes ride on one `appsignal.error_causes` JSON attribute
      # (keys match the processor's `ErrorSubCause`); separate cause events would
      # each become their own incident.
      def set_error(class_name, message, backtrace, causes, _root_cause_missing)
        span = current_span

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
                "lines" => cause[:backtrace] || []
              }
            end
          )
        end

        span.add_event("exception", :attributes => attributes)
        span.status = ::OpenTelemetry::Trace::Status.error
      end

      # Emits a breadcrumb as an `appsignal.breadcrumb` span event on AppSignal's
      # current span -- the open event span, falling back to the root -- not the
      # OTel current span, which may belong to another instrumentation.
      # Breadcrumbs are emitted immediately (not flushed at completion) because by
      # completion the event span has finished, and the OTel SDK drops events
      # added to an ended span.
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
        current_span.add_event(
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
        # `teardown` sets `@completed`, so this guard also makes the metric
        # idempotent across a double `complete`, and skips it on `discard`.
        emit_queue_duration_metric unless @completed
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

      # Each error is recorded eagerly as its own `exception` event on the span
      # current when it was added, so the Transaction never duplicates itself --
      # which is why `duplicate` is left unimplemented (see BaseBackend).
      def records_errors_eagerly?
        true
      end

      # Returned so `Transaction#to_h` (`JSON.parse(@backend.to_json)`) yields an
      # empty Hash. Collector mode asserts on emitted spans, not `to_h`.
      def to_json # rubocop:disable Lint/ToJSON
        "{}"
      end

      private

      # Detaches the OTel context and finishes the root span. Idempotent: the
      # Transaction can complete directly and again via a cleanup path, and
      # re-detaching/re-finishing an ended span would error.
      def teardown
        return if @completed

        @completed = true
        # Release any event span left unfinished by an aborted flow, so the
        # root context can detach in LIFO order.
        until @event_stack.empty?
          span, token = @event_stack.pop
          ::OpenTelemetry::Context.detach(token)
          span.finish
        end
        ::OpenTelemetry::Context.detach(@context_token) if @context_token
        @span&.finish
      end

      # Emits the queue duration as a distribution metric in both the
      # per-namespace and per-namespace-and-host series the queue-time graph
      # reads. Nothing downstream fans these out, so emit both ourselves.
      def emit_queue_duration_metric
        return unless @queue_start

        duration_ms = (@start_time.to_f * 1000) - @queue_start
        return if duration_ms.negative?

        Appsignal::Metrics::OpenTelemetryBackend.add_distribution_value(
          "transaction_queue_duration", duration_ms, :namespace => @namespace
        )
        Appsignal::Metrics::OpenTelemetryBackend.add_distribution_value(
          "transaction_queue_duration", duration_ms,
          :namespace => @namespace, :hostname => hostname
        )
      end

      def hostname
        Appsignal.config&.[](:hostname) || Socket.gethostname
      end

      def tracer
        ::OpenTelemetry.tracer_provider.tracer(TRACER_NAME, Appsignal::VERSION)
      end

      # The open event span, or the root span when no event is open. Not the OTel
      # current span, which may belong to another instrumentation.
      def current_span
        span, _token = @event_stack.last
        span || @span
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
