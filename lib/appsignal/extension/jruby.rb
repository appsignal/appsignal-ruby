# frozen_string_literal: true

require "ffi"

module Appsignal
  class Extension
    # JRuby extension wrapper
    #
    # Only loaded if the system is detected as JRuby.
    #
    # @api private
    module Jruby # rubocop:disable Metrics/ModuleLength
      extend FFI::Library

      # JRuby extension String helpers.
      #
      # Based on the make_appsignal_string and make_ruby_string helpers from the
      # AppSignal C-extension in `ext/appsignal_extension.c`.
      module StringHelpers
        class AppsignalString < FFI::Struct
          layout :len, :size_t,
            :buf, :pointer
        end

        def make_appsignal_string(ruby_string)
          raise ArgumentError, "argument is not a string" unless ruby_string.is_a?(String)

          AppsignalString.new.tap do |appsignal_string|
            appsignal_string[:len] = ruby_string.bytesize
            appsignal_string[:buf] = FFI::MemoryPointer.from_string(ruby_string)
          end
        end

        def make_ruby_string(appsignal_string)
          appsignal_string[:buf].read_string(appsignal_string[:len]).tap do |ruby_string|
            ruby_string.force_encoding(Encoding::UTF_8)
          end
        end
      end
      include StringHelpers

      def self.lib_extension
        if Appsignal::System.agent_platform.include?("darwin")
          "dylib"
        else
          "so"
        end
      end

      begin
        begin
          # RubyGems will install the extension in the gem's lib directory.
          ffi_lib File.join(File.dirname(__FILE__), "../../../lib/libappsignal.#{lib_extension}")
        rescue LoadError
          ffi_lib File.join(File.dirname(__FILE__), "../../../ext/libappsignal.#{lib_extension}")
        end
        typedef AppsignalString.by_value, :appsignal_string

        attach_function :appsignal_start, [], :void
        attach_function :appsignal_stop, [], :void
        attach_function :appsignal_diagnose, [], :appsignal_string
        attach_function :appsignal_get_server_state,
          [:appsignal_string],
          :appsignal_string
        attach_function :appsignal_running_in_container, [], :bool
        attach_function :appsignal_set_environment_metadata,
          [:appsignal_string, :appsignal_string],
          :void

        # Metrics methods
        attach_function :appsignal_set_gauge,
          [:appsignal_string, :double, :pointer],
          :void
        attach_function :appsignal_increment_counter,
          [:appsignal_string, :double, :pointer],
          :void
        attach_function :appsignal_add_distribution_value,
          [:appsignal_string, :double, :pointer],
          :void

        # Logging methods
        attach_function :appsignal_log,
          [:appsignal_string, :int32, :appsignal_string, :pointer],
          :void

        # Transaction methods
        attach_function :appsignal_free_transaction,
          [:pointer],
          :void
        attach_function :appsignal_start_transaction,
          [:appsignal_string, :appsignal_string, :long],
          :pointer
        attach_function :appsignal_start_event,
          [:pointer, :long],
          :void
        attach_function :appsignal_finish_event,
          [:pointer, :appsignal_string, :appsignal_string, :appsignal_string, :int64,
           :long],
          :void
        attach_function :appsignal_finish_event_data,
          [:pointer, :appsignal_string, :appsignal_string, :pointer, :int64, :long],
          :void
        attach_function :appsignal_record_event,
          [:pointer, :appsignal_string, :appsignal_string, :appsignal_string, :int64,
           :long, :long],
          :void
        attach_function :appsignal_record_event_data,
          [:pointer, :appsignal_string, :appsignal_string, :pointer, :int64, :long,
           :long],
          :void
        attach_function :appsignal_set_transaction_error,
          [:pointer, :appsignal_string, :appsignal_string, :pointer],
          :void
        attach_function :appsignal_set_transaction_action,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_set_transaction_namespace,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_set_transaction_sample_data,
          [:pointer, :appsignal_string, :pointer],
          :void
        attach_function :appsignal_set_transaction_queue_start,
          [:pointer, :long],
          :void
        attach_function :appsignal_set_transaction_metadata,
          [:pointer, :appsignal_string, :appsignal_string],
          :void
        attach_function :appsignal_finish_transaction,
          [:pointer, :long],
          :void
        attach_function :appsignal_complete_transaction,
          [:pointer],
          :void
        attach_function :appsignal_transaction_to_json,
          [:pointer],
          :appsignal_string

        # Span methods
        attach_function :appsignal_create_root_span,
          [:appsignal_string],
          :pointer
        attach_function :appsignal_create_root_span_with_timestamp,
          [:appsignal_string, :int64, :int64],
          :pointer
        attach_function :appsignal_create_child_span,
          [:pointer],
          :pointer
        attach_function :appsignal_create_child_span_with_timestamp,
          [:pointer, :int64, :int64],
          :pointer
        attach_function :appsignal_create_span_from_traceparent,
          [:appsignal_string],
          :pointer
        attach_function :appsignal_span_id,
          [:pointer],
          :appsignal_string
        attach_function :appsignal_span_to_json,
          [:pointer],
          :appsignal_string
        attach_function :appsignal_set_span_name,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_set_span_namespace,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_add_span_error,
          [:pointer, :appsignal_string, :appsignal_string, :pointer],
          :void
        attach_function :appsignal_set_span_sample_data,
          [:pointer, :appsignal_string, :pointer],
          :void
        attach_function :appsignal_set_span_attribute_string,
          [:pointer, :appsignal_string, :appsignal_string],
          :void
        attach_function :appsignal_set_span_attribute_sql_string,
          [:pointer, :appsignal_string, :appsignal_string],
          :void
        attach_function :appsignal_set_span_attribute_int,
          [:pointer, :appsignal_string, :int64],
          :void
        attach_function :appsignal_set_span_attribute_bool,
          [:pointer, :appsignal_string, :bool],
          :void
        attach_function :appsignal_set_span_attribute_double,
          [:pointer, :appsignal_string, :double],
          :void
        attach_function :appsignal_close_span,
          [:pointer],
          :void
        attach_function :appsignal_close_span_with_timestamp,
          [:pointer, :int64, :int64],
          :void
        attach_function :appsignal_free_span,
          [:pointer],
          :void

        # Data struct methods
        attach_function :appsignal_free_data, [:pointer], :void
        attach_function :appsignal_data_map_new, [], :pointer
        attach_function :appsignal_data_array_new, [], :pointer
        attach_function :appsignal_data_map_set_string,
          [:pointer, :appsignal_string, :appsignal_string],
          :void
        attach_function :appsignal_data_map_set_integer,
          [:pointer, :appsignal_string, :int64],
          :void
        attach_function :appsignal_data_map_set_float,
          [:pointer, :appsignal_string, :double],
          :void
        attach_function :appsignal_data_map_set_boolean,
          [:pointer, :appsignal_string, :bool],
          :void
        attach_function :appsignal_data_map_set_null,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_data_map_set_data,
          [:pointer, :appsignal_string, :pointer],
          :void
        attach_function :appsignal_data_array_append_string,
          [:pointer, :appsignal_string],
          :void
        attach_function :appsignal_data_array_append_integer,
          [:pointer, :int64],
          :void
        attach_function :appsignal_data_array_append_float,
          [:pointer, :double],
          :void
        attach_function :appsignal_data_array_append_boolean,
          [:pointer, :bool],
          :void
        attach_function :appsignal_data_array_append_null,
          [:pointer],
          :void
        attach_function :appsignal_data_array_append_data,
          [:pointer, :pointer],
          :void
        attach_function :appsignal_data_equal,
          [:pointer, :pointer],
          :bool
        attach_function :appsignal_data_to_json,
          [:pointer],
          :appsignal_string

        Appsignal.extension_loaded = true if Appsignal.respond_to? :extension_loaded=
      rescue LoadError => error
        error_message = "ERROR: AppSignal failed to load extension. " \
          "Please run `appsignal diagnose` and email us at support@appsignal.com\n" \
          "#{error.class}: #{error.message}"
        Appsignal.internal_logger.error(error_message) if Appsignal.respond_to? :internal_logger
        Kernel.warn error_message
        Appsignal.extension_loaded = false if Appsignal.respond_to? :extension_loaded=
        raise error if ENV["_APPSIGNAL_EXTENSION_INSTALL"] == "true"
      end

      def start
        appsignal_start
      end

      def stop
        appsignal_stop
      end

      def diagnose
        make_ruby_string(appsignal_diagnose)
      end

      def get_server_state(key)
        state = appsignal_get_server_state(make_appsignal_string(key))
        make_ruby_string state if state[:len] > 0
      end

      def log(group, level, message, attributes)
        appsignal_log(
          make_appsignal_string(group),
          level,
          make_appsignal_string(message),
          attributes.pointer
        )
      end

      def start_transaction(transaction_id, namespace, gc_duration_ms)
        transaction = appsignal_start_transaction(
          make_appsignal_string(transaction_id),
          make_appsignal_string(namespace),
          gc_duration_ms
        )

        return if !transaction || transaction.null?

        Transaction.new(transaction)
      end

      def data_map_new
        Data.new(appsignal_data_map_new)
      end

      def data_array_new
        Data.new(appsignal_data_array_new)
      end

      def running_in_container?
        appsignal_running_in_container
      end

      def set_environment_metadata(key, value)
        appsignal_set_environment_metadata(
          make_appsignal_string(key),
          make_appsignal_string(value)
        )
      end

      def set_gauge(key, value, tags)
        appsignal_set_gauge(make_appsignal_string(key), value, tags.pointer)
      end

      def increment_counter(key, value, tags)
        appsignal_increment_counter(make_appsignal_string(key), value, tags.pointer)
      end

      def add_distribution_value(key, value, tags)
        appsignal_add_distribution_value(make_appsignal_string(key), value, tags.pointer)
      end

      class Transaction
        include StringHelpers

        attr_reader :pointer

        def initialize(pointer)
          @pointer = FFI::AutoPointer.new(
            pointer,
            Extension.method(:appsignal_free_transaction)
          )
        end

        def start_event(gc_duration_ms)
          Extension.appsignal_start_event(pointer, gc_duration_ms)
        end

        def finish_event(name, title, body, body_format, gc_duration_ms)
          case body
          when String
            method = :appsignal_finish_event
            body_arg = make_appsignal_string(body)
          when Data
            method = :appsignal_finish_event_data
            body_arg = body.pointer
          else
            raise ArgumentError,
              "body argument should be a String or Appsignal::Extension::Data"
          end
          Extension.public_send(
            method,
            pointer,
            make_appsignal_string(name),
            make_appsignal_string(title),
            body_arg,
            body_format,
            gc_duration_ms
          )
        end

        def record_event(name, title, body, body_format, duration, gc_duration_ms) # rubocop:disable Metrics/ParameterLists
          case body
          when String
            method = :appsignal_record_event
            body_arg = make_appsignal_string(body)
          when Data
            method = :appsignal_record_event_data
            body_arg = body.pointer
          else
            raise ArgumentError,
              "body argument should be a String or Appsignal::Extension::Data"
          end
          Extension.public_send(
            method,
            pointer,
            make_appsignal_string(name),
            make_appsignal_string(title),
            body_arg,
            body_format,
            duration,
            gc_duration_ms
          )
        end

        def set_error(name, message, backtrace)
          Extension.appsignal_set_transaction_error(
            pointer,
            make_appsignal_string(name),
            make_appsignal_string(message),
            backtrace.pointer
          )
        end

        def set_action(action_name) # rubocop:disable Naming/AccessorMethodName
          Extension.appsignal_set_transaction_action(
            pointer,
            make_appsignal_string(action_name)
          )
        end

        def set_namespace(namespace) # rubocop:disable Naming/AccessorMethodName
          Extension.appsignal_set_transaction_namespace(
            pointer,
            make_appsignal_string(namespace)
          )
        end

        def set_sample_data(key, payload)
          Extension.appsignal_set_transaction_sample_data(
            pointer,
            make_appsignal_string(key),
            payload.pointer
          )
        end

        def set_queue_start(time) # rubocop:disable Naming/AccessorMethodName
          Extension.appsignal_set_transaction_queue_start(pointer, time)
        end

        def set_metadata(key, value)
          Extension.appsignal_set_transaction_metadata(
            pointer,
            make_appsignal_string(key),
            make_appsignal_string(value)
          )
        end

        def finish(gc_duration_ms)
          Extension.appsignal_finish_transaction(pointer, gc_duration_ms)
        end

        def complete
          Extension.appsignal_complete_transaction(pointer)
        end

        def to_json # rubocop:disable Lint/ToJSON
          json = Extension.appsignal_transaction_to_json(pointer)
          make_ruby_string(json) if json[:len] > 0
        end
      end

      class Span
        include StringHelpers
        extend StringHelpers

        attr_reader :pointer

        def initialize(pointer)
          @pointer = FFI::AutoPointer.new(
            pointer,
            Extension.method(:appsignal_free_span)
          )
        end

        def self.root(namespace)
          namespace = make_appsignal_string(namespace)
          Span.new(Extension.appsignal_create_root_span(namespace))
        end

        def child
          Span.new(Extension.appsignal_create_child_span(pointer))
        end

        def add_error(name, message, backtrace)
          Extension.appsignal_add_span_error(
            pointer,
            make_appsignal_string(name),
            make_appsignal_string(message),
            backtrace.pointer
          )
        end

        def set_sample_data(key, payload)
          Extension.appsignal_set_span_sample_data(
            pointer,
            make_appsignal_string(key),
            payload.pointer
          )
        end

        def set_name(name) # rubocop:disable Naming/AccessorMethodName
          Extension.appsignal_set_span_name(
            pointer,
            make_appsignal_string(name)
          )
        end

        def set_attribute_string(key, value)
          Extension.appsignal_set_span_attribute_string(
            pointer,
            make_appsignal_string(key),
            make_appsignal_string(value)
          )
        end

        def set_attribute_int(key, value)
          Extension.appsignal_set_span_attribute_int(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def set_attribute_bool(key, value)
          Extension.appsignal_set_span_attribute_bool(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def set_attribute_double(key, value)
          Extension.appsignal_set_span_attribute_double(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def to_json # rubocop:disable Lint/ToJSON
          json = Extension.appsignal_span_to_json(pointer)
          make_ruby_string(json) if json[:len] > 0
        end

        def close
          Extension.appsignal_close_span(pointer)
        end
      end

      class Data
        include StringHelpers
        attr_reader :pointer

        def initialize(pointer)
          @pointer = FFI::AutoPointer.new(
            pointer,
            Extension.method(:appsignal_free_data)
          )
        end

        def set_string(key, value)
          Extension.appsignal_data_map_set_string(
            pointer,
            make_appsignal_string(key),
            make_appsignal_string(value)
          )
        end

        def set_integer(key, value)
          Extension.appsignal_data_map_set_integer(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def set_float(key, value)
          Extension.appsignal_data_map_set_float(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def set_boolean(key, value)
          Extension.appsignal_data_map_set_boolean(
            pointer,
            make_appsignal_string(key),
            value
          )
        end

        def set_nil(key) # rubocop:disable Naming/AccessorMethodName
          Extension.appsignal_data_map_set_null(
            pointer,
            make_appsignal_string(key)
          )
        end

        def set_data(key, value)
          Extension.appsignal_data_map_set_data(
            pointer,
            make_appsignal_string(key),
            value.pointer
          )
        end

        def append_string(value)
          Extension.appsignal_data_array_append_string(
            pointer,
            make_appsignal_string(value)
          )
        end

        def append_integer(value)
          Extension.appsignal_data_array_append_integer(pointer, value)
        end

        def append_float(value)
          Extension.appsignal_data_array_append_float(pointer, value)
        end

        def append_boolean(value)
          Extension.appsignal_data_array_append_boolean(pointer, value)
        end

        def append_nil
          Extension.appsignal_data_array_append_null(pointer)
        end

        def append_data(value)
          Extension.appsignal_data_array_append_data(pointer, value.pointer)
        end

        def ==(other)
          Extension.appsignal_data_equal(pointer, other.pointer)
        end

        def to_s
          make_ruby_string Extension.appsignal_data_to_json(pointer)
        end
      end
    end
  end
end
