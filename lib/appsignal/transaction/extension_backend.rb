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
    class ExtensionBackend < BaseBackend
      # rubocop:disable Layout/LineLength
      BACKTRACE_REGEX =
        %r{(?<gem>[\w-]+ \(.+\) )?(?<path>:?/?\w+?.+?):(?<line>:?\d+)(?::in `(?<method>.+)')?$}.freeze
      # rubocop:enable Layout/LineLength

      # @!visibility private
      attr_writer :breadcrumbs

      # The `opentelemetry_*` keyword arguments (context, kind and
      # relationship) shape the OpenTelemetry span in collector mode. Agent mode
      # has no notion of them, so they are accepted and ignored. They are listed
      # explicitly, rather than swallowed with `**`, so an unexpected keyword
      # still raises, matching the OpenTelemetry backend.
      # rubocop:disable Metrics/ParameterLists, Lint/UnusedMethodArgument
      def initialize(
        transaction_id,
        namespace,
        handle: nil,
        opentelemetry_context: nil,
        opentelemetry_kind: nil,
        opentelemetry_relationship: nil
      )
        super()
        @handle = handle ||
          Appsignal::Extension.start_transaction(transaction_id, namespace, 0) ||
          Appsignal::Extension::MockTransaction.new
        @breadcrumbs = []
      end
      # rubocop:enable Metrics/ParameterLists, Lint/UnusedMethodArgument

      # Agent mode has no span kind; `opentelemetry_kind` is ignored here.
      def start_event(opentelemetry_kind: nil) # rubocop:disable Lint/UnusedMethodArgument
        @handle.start_event(0)
      end

      def finish_event(name, title, body, body_format)
        @handle.finish_event(name, title, body, body_format, 0)
      end

      # Agent mode has no span kind; `opentelemetry_kind` is ignored here.
      def record_event(name, title, body, body_format, duration, opentelemetry_kind: nil) # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        @handle.record_event(name, title, body, body_format, duration, 0)
      end

      def set_action(action)
        @handle.set_action(action)
      end

      def set_namespace(namespace)
        @handle.set_namespace(namespace)
      end

      def set_queue_start(start)
        @handle.set_queue_start(start)
      end

      def set_metadata(key, value)
        @handle.set_metadata(key, value)
      end

      # The agent has a single params slot, so every params channel maps to one
      # `:params` bucket. The transaction merges the channels into it, and only
      # the `:params` key ever reaches `set_sample_data`.
      def params_mapping
        {
          :params => :params,
          :request_payload => :params,
          :function_parameters => :params
        }
      end

      # `data` is a raw Ruby Hash/Array; the C extension wants a `Data` object,
      # so serialize it here (mirrors how `set_error` serializes its backtrace).
      def set_sample_data(key, data)
        @handle.set_sample_data(key, Appsignal::Utils::Data.generate(data))
      end

      # Buffer breadcrumbs, keeping the last `BREADCRUMB_LIMIT`, and flush them as
      # sample data on completion.
      def add_breadcrumb(breadcrumb)
        @breadcrumbs.push(breadcrumb)
        @breadcrumbs = @breadcrumbs.last(Appsignal::Transaction::BREADCRUMB_LIMIT)
      end

      # Serializes the backtrace to a C-extension `Data` object and records the
      # error, then flushes the causes as `error_causes` sample data in the
      # agent's first-line shape.
      def set_error(class_name, message, backtrace, causes, root_cause_missing)
        backtrace_data =
          if backtrace
            Appsignal::Utils::Data.generate(backtrace)
          else
            Appsignal::Extension.data_array_new
          end
        @handle.set_error(class_name, message, backtrace_data)

        set_sample_data("error_causes", error_causes_sample_data(causes, root_cause_missing))
      end

      def finish
        @handle.finish(0)
      end

      def complete
        unless @breadcrumbs.empty?
          @handle.set_sample_data("breadcrumbs", Appsignal::Utils::Data.generate(@breadcrumbs))
        end
        @handle.complete
      end

      # Discarding in agent mode drops the transaction: the extension handle is
      # simply abandoned and never told to complete, so nothing is sent. There
      # is no `ignore_subtrace` concept on the agent path. This mirrors the
      # pre-backend behavior, where `Transaction#complete` returned before
      # touching the handle on a discarded transaction.
      def discard
      end

      # The extension transaction holds a single error, so the Transaction
      # reports additional errors as duplicate transactions instead.
      def supports_multiple_errors?
        false
      end

      def duplicate(new_transaction_id)
        self.class.new(
          new_transaction_id, nil, :handle => @handle.duplicate(new_transaction_id)
        ).tap { |backend| backend.breadcrumbs = @breadcrumbs.dup }
      end

      def to_json # rubocop:disable Lint/ToJSON
        @handle.to_json
      end

      private

      # Projects the neutral causes to the agent's first-line shape. A truncated
      # chain marks its last entry as not the root cause.
      def error_causes_sample_data(causes, root_cause_missing)
        sample_data = causes.map do |cause|
          {
            :name => cause[:name],
            :message => cause[:message],
            :first_line => first_formatted_backtrace_line(cause[:backtrace])
          }
        end
        sample_data.last[:is_root_cause] = false if root_cause_missing && sample_data.any?
        sample_data
      end

      # Parses the first backtrace line into the fields the UI links on (gem,
      # path, line, method), with the path made relative to the app root.
      def first_formatted_backtrace_line(backtrace)
        first_line = backtrace&.first
        return unless first_line

        captures = BACKTRACE_REGEX.match(first_line)
        return unless captures

        captures.named_captures
          .merge("original" => first_line)
          .tap do |c|
            config = Appsignal.config
            c["gem"] = c["gem"]&.strip
            root_path = config.root_path
            if c["path"].start_with?(root_path)
              c["path"].delete_prefix!(root_path)
              c["path"].delete_prefix!("/")
            end
            c["revision"] = config[:revision]
            c["line"] = c["line"].to_i
          end
      end
    end
  end
end
