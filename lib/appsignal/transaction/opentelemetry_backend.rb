# frozen_string_literal: true

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The transaction backend used in collector mode. Emits an OpenTelemetry
    # root span for the transaction lifecycle. Child spans for events and
    # exception events for errors land in subsequent steps.
    #
    # On construction the backend starts an OTel root span and attaches it
    # to the current OpenTelemetry context, so any third-party OTel
    # instrumentation that runs while the transaction is active nests
    # naturally under the transaction's span. On `complete` the backend
    # detaches the context and finishes the span. All other write methods
    # are still no-ops for now.
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

      def initialize(transaction_id, namespace, gc_duration, **)
        @transaction_id = transaction_id
        @namespace = namespace
        @gc_duration = gc_duration
        @completed = false

        @span = tracer.start_span(
          placeholder_span_name(namespace),
          :kind => SPAN_KIND_BY_NAMESPACE.fetch(namespace, DEFAULT_SPAN_KIND)
        )
        @context_token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(@span)
        )
      end

      def start_event(_gc_duration)
      end

      def finish_event(_name, _title, _body, _body_format, _gc_duration)
      end

      def record_event(_name, _title, _body, _body_format, _duration, _gc_duration)
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
    end
  end
end
