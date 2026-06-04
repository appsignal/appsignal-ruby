# frozen_string_literal: true

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The transaction backend used in agent mode. Wraps a per-transaction
    # handle on the C extension (`Appsignal::Extension::Transaction`) and
    # forwards every call to it.
    #
    # In agent mode `Appsignal::Backends.transaction` returns this class;
    # `Appsignal::Transaction#initialize` instantiates one and stores it in
    # `@backend`.
    class ExtensionBackend
      def initialize(transaction_id, namespace, gc_duration, handle: nil)
        @handle = handle ||
          Appsignal::Extension.start_transaction(transaction_id, namespace, gc_duration) ||
          Appsignal::Extension::MockTransaction.new
      end

      def start_event(gc_duration)
        @handle.start_event(gc_duration)
      end

      def finish_event(name, title, body, body_format, gc_duration)
        @handle.finish_event(name, title, body, body_format, gc_duration)
      end

      def record_event(name, title, body, body_format, duration, gc_duration) # rubocop:disable Metrics/ParameterLists
        @handle.record_event(name, title, body, body_format, duration, gc_duration)
      end

      def set_action(action) # rubocop:disable Naming/AccessorMethodName
        @handle.set_action(action)
      end

      def set_namespace(namespace) # rubocop:disable Naming/AccessorMethodName
        @handle.set_namespace(namespace)
      end

      def set_queue_start(start) # rubocop:disable Naming/AccessorMethodName
        @handle.set_queue_start(start)
      end

      def set_metadata(key, value)
        @handle.set_metadata(key, value)
      end

      def set_sample_data(key, data)
        @handle.set_sample_data(key, data)
      end

      # `backtrace` is a raw Array (or nil); the C extension wants a `Data`
      # object, so serialize it here. `causes` is unused in agent mode -- the
      # Transaction reports causes separately via the `error_causes` sample data.
      def set_error(class_name, message, backtrace, _causes)
        backtrace_data =
          if backtrace
            Appsignal::Utils::Data.generate(backtrace)
          else
            Appsignal::Extension.data_array_new
          end
        @handle.set_error(class_name, message, backtrace_data)
      end

      def finish(gc_duration)
        @handle.finish(gc_duration)
      end

      def complete
        @handle.complete
      end

      # The extension transaction holds a single error, so the Transaction
      # reports additional errors as duplicate transactions.
      def supports_multiple_errors?
        false
      end

      def duplicate(new_transaction_id)
        self.class.new(new_transaction_id, nil, 0, :handle => @handle.duplicate(new_transaction_id))
      end

      def to_json # rubocop:disable Lint/ToJSON
        @handle.to_json
      end

      # Test-mode introspection. The `Appsignal::Extension::Transaction` patches
      # in `spec/support/testing.rb` add `queue_start` and `_completed?` on the
      # underlying handle; matchers reach in via `transaction.backend.<reader>`.
      def queue_start
        @handle.queue_start
      end

      def _completed?
        @handle._completed?
      end
    end
  end
end
