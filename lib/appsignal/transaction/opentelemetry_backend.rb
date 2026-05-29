# frozen_string_literal: true

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
        "http_request"   => :server,
        "action_cable"   => :server,
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

      def initialize(transaction_id, namespace, gc_duration, **)
        @transaction_id = transaction_id
        @namespace = namespace
        @gc_duration = gc_duration
        @completed = false
        @event_stack = []

        @span = tracer.start_span(
          placeholder_span_name(namespace),
          :kind => SPAN_KIND_BY_NAMESPACE.fetch(namespace, DEFAULT_SPAN_KIND)
        )
        @context_token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(@span)
        )
      end

      def start_event(_gc_duration)
        span = tracer.start_span(EVENT_SPAN_PLACEHOLDER_NAME)
        token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(span)
        )
        @event_stack.push([span, token])
      end

      def finish_event(name, title, body, body_format, _gc_duration)
        return if @event_stack.empty?

        span, token = @event_stack.pop
        span.name = name
        write_event_body_attributes(span, body, body_format)
        span.set_attribute("appsignal.title", title) if title && !title.empty?
        ::OpenTelemetry::Context.detach(token)
        span.finish
      end

      def record_event(name, title, body, body_format, duration, _gc_duration)
        start_time = Time.now - (duration / 1_000_000_000.0)
        span = tracer.start_span(name, :start_timestamp => start_time)
        write_event_body_attributes(span, body, body_format)
        span.set_attribute("appsignal.title", title) if title && !title.empty?
        span.finish
      end

      def set_action(_action) # rubocop:disable Naming/AccessorMethodName
      end

      def set_namespace(_namespace) # rubocop:disable Naming/AccessorMethodName
      end

      def set_queue_start(_start) # rubocop:disable Naming/AccessorMethodName
      end

      def set_metadata(_key, _value)
      end

      def set_sample_data(_key, _data)
      end

      def set_error(_class_name, _message, _backtrace_data)
      end

      # Always returns `false` for now: there is no sample data flush in
      # collector mode (the OTel span carries the data itself once span
      # emission lands in later steps).
      def finish(_gc_duration)
        false
      end

      def complete
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

      def duplicate(new_transaction_id)
        self.class.new(new_transaction_id, @namespace, 0)
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

      def tracer
        ::OpenTelemetry.tracer_provider.tracer(TRACER_NAME, Appsignal::VERSION)
      end

      def placeholder_span_name(namespace)
        "appsignal.transaction #{namespace}"
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
