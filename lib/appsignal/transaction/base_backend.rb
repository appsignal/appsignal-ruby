# frozen_string_literal: true

module Appsignal
  class Transaction
    # @!visibility private
    #
    # The interface every transaction backend implements. `Appsignal::Backends
    # .transaction` picks a concrete backend per mode -- ExtensionBackend in
    # agent mode, OpenTelemetryBackend in collector mode. This base documents the
    # contract; a backend that leaves a method unimplemented raises here.
    class BaseBackend
      # Instrumented events.
      def start_event(opentelemetry_kind: nil)
        raise NotImplementedError
      end

      def finish_event(_name, _title, _body, _body_format)
        raise NotImplementedError
      end

      def record_event(_name, _title, _body, _body_format, _duration, opentelemetry_kind: nil) # rubocop:disable Metrics/ParameterLists
        raise NotImplementedError
      end

      # Transaction metadata.
      def set_action(_action)
        raise NotImplementedError
      end

      def set_namespace(_namespace)
        raise NotImplementedError
      end

      def set_metadata(_key, _value)
        raise NotImplementedError
      end

      def set_queue_start(_start)
        raise NotImplementedError
      end

      # Sample data (params, session, tags, ...), breadcrumbs and errors.
      def set_sample_data(_key, _data)
        raise NotImplementedError
      end

      def add_breadcrumb(_breadcrumb)
        raise NotImplementedError
      end

      def set_error(_class_name, _message, _backtrace, _causes, _root_cause_missing)
        raise NotImplementedError
      end

      # Whether the backend can hold more than one error on a single
      # transaction. When it can't (agent mode), the Transaction reports the
      # extra errors as duplicate transactions instead.
      def supports_multiple_errors?
        raise NotImplementedError
      end

      # Lifecycle.
      def finish
        raise NotImplementedError
      end

      def complete
        raise NotImplementedError
      end

      def discard
        raise NotImplementedError
      end

      # Only used when `supports_multiple_errors?` is false (agent mode).
      # Backends that support multiple errors never duplicate and leave this
      # unimplemented.
      def duplicate(_new_transaction_id)
        raise NotImplementedError
      end

      def to_json # rubocop:disable Lint/ToJSON
        raise NotImplementedError
      end
    end
  end
end
