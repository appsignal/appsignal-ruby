# frozen_string_literal: true

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The transaction backend used in collector mode. Will eventually emit
    # OpenTelemetry spans for the transaction lifecycle (root span on
    # creation, child spans for events, exception events on errors).
    #
    # Step 1 of the transaction OTel migration only scaffolds the seam:
    # every write method is a no-op, `finish` returns `false` so the
    # `Transaction#complete` sampling path doesn't run, and `to_json`
    # returns `"{}"` so `Transaction#to_h` does not raise if called in
    # collector mode.
    class OpenTelemetryBackend
      def initialize(transaction_id, namespace, gc_duration, **)
        @transaction_id = transaction_id
        @namespace = namespace
        @gc_duration = gc_duration
        @completed = false
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
    end
  end
end
