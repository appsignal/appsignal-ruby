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

      # Guards the process-wide warn-once state, which transactions touch
      # concurrently on threaded servers. A constant so it is created once at
      # load time rather than lazily (which would race).
      WARN_ONCE_LOCK = Mutex.new

      class << self
        # Logs the block's message the first time it sees `key`, then stays quiet
        # for that key for the rest of the process. Used for warnings that would
        # otherwise repeat on every transaction. The message is built lazily, so
        # a deduplicated call skips building it. The check-and-set is locked so
        # concurrent transactions cannot both warn.
        def warn_once(key)
          first_time = WARN_ONCE_LOCK.synchronize do
            next false if warned_keys.key?(key)

            warned_keys[key] = true
          end
          Appsignal.internal_logger.warn(yield) if first_time
        end

        # @!visibility private
        # Resets the warn-once state. Only used to keep test runs isolated.
        def clear_warned!
          WARN_ONCE_LOCK.synchronize { warned_keys.clear }
        end

        private

        def warned_keys
          @warned_keys ||= {}
        end
      end

      # Collector treats SERVER/CONSUMER spans as subtrace roots; SERVER is the
      # safe default when no kind is given (a transaction is almost always an
      # external-triggered unit of work).
      DEFAULT_SPAN_KIND = :server

      # The span kinds a transaction may take. An unknown value would raise
      # inside OpenTelemetry span creation, so it falls back to the default.
      SPAN_KINDS = [:server, :consumer, :producer, :internal].freeze

      # How the transaction's span relates to an incoming OpenTelemetry context
      # when none is given. A web request continues the upstream trace, so
      # parenting is the safe default.
      DEFAULT_RELATIONSHIP = :parent

      # How the transaction's span may relate to an incoming context. An unknown
      # value would silently behave like `:none`, so it falls back to the
      # default instead.
      RELATIONSHIPS = [:parent, :link, :both, :none].freeze

      # The collector expects "web"/"background"; the agent's processor converts
      # these internal namespaces in agent mode, but nothing does in collector
      # mode. Other namespaces pass through unchanged.
      DISPLAY_NAMESPACE = {
        "http_request" => "web",
        "background_job" => "background"
      }.freeze

      # Placeholder name an event span carries between `start_event` and
      # `finish_event`. `finish_event` overwrites it with the AS::N event name,
      # so it only surfaces when `complete` has to drain a span that was started
      # but never finished. It is deliberately an obvious placeholder rather
      # than a plausible event name, so such a span reads as the unfinished
      # event it is and is not mistaken for a real one.
      EVENT_SPAN_PLACEHOLDER_NAME = "[unfinished transaction event]"

      # Sentinel value the AppSignal collector recognizes as "a SQL system
      # we don't know the specific dialect of" — sufficient to trigger SQL
      # sanitization on `db.query.text`.
      SQL_DB_SYSTEM = "other_sql"

      # Epoch-ms floor (~year 2000) below which a queue start is ignored. Mirrors
      # the agent's `set_queue_start` (ext `transaction.rs`), which only records a
      # queue duration when `queue_start_ms > 946_681_200_000`.
      QUEUE_START_MIN = 946_681_200_000

      # One open event on the event stack. Holds the OpenTelemetry span and the
      # context token attached for it, plus the allocation bookkeeping for the
      # event. `allocation_start` is the allocation counter when the event began
      # (nil when allocation tracking is off), and `child_allocation_count`
      # accumulates the full allocation counts of the event's finished children,
      # so the event's own allocations are `full - child_allocation_count`.
      EventFrame = Struct.new(:span, :token, :allocation_start, :child_allocation_count)

      def initialize( # rubocop:disable Metrics/ParameterLists
        transaction_id,
        namespace,
        opentelemetry_context: nil,
        opentelemetry_scope: nil,
        opentelemetry_kind: nil,
        opentelemetry_relationship: nil
      )
        super()
        @transaction_id = transaction_id
        @namespace = namespace
        @scope = opentelemetry_scope
        @completed = false
        @event_stack = []
        @breadcrumb_count = 0
        @queue_start = nil
        @start_time = Time.now
        @action_set = false
        @action = nil
        @allocation_start = current_allocation_count
        @root_child_allocation_count = 0

        kind = validated_option(
          opentelemetry_kind, SPAN_KINDS, DEFAULT_SPAN_KIND, "opentelemetry_kind"
        )
        relationship = validated_option(
          opentelemetry_relationship, RELATIONSHIPS, DEFAULT_RELATIONSHIP,
          "opentelemetry_relationship"
        )
        @span = start_transaction_span(namespace, kind, relationship, opentelemetry_context)
        @context_token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(@span)
        )

        # Transaction#initialize sets the namespace directly without calling
        # set_namespace, so emit the attribute from here.
        @span.set_attribute("appsignal.namespace", display_namespace(namespace)) if namespace
      end

      # `opentelemetry_kind` (e.g. `:client` for an outgoing HTTP request) is set
      # at span creation because OTel span kind is immutable afterwards. `nil`
      # leaves the SDK default (INTERNAL).
      def start_event(opentelemetry_kind: nil, opentelemetry_scope: nil)
        span = tracer_for(opentelemetry_scope)
          .start_span(EVENT_SPAN_PLACEHOLDER_NAME, :kind => opentelemetry_kind)
        token = ::OpenTelemetry::Context.attach(
          ::OpenTelemetry::Trace.context_with_span(span)
        )
        push_event(span, token)
      end

      def finish_event(name, title, body, body_format)
        return if @event_stack.empty?

        frame = @event_stack.pop
        write_event_span_name(frame.span, name, title)
        write_event_body_attributes(frame.span, body, body_format)
        write_event_allocation_count(frame)
        ::OpenTelemetry::Context.detach(frame.token)
        frame.span.finish
      end

      # `opentelemetry_kind` is set at span creation (kind is immutable in OTel),
      # mirroring `start_event`. `nil` leaves the SDK default (INTERNAL).
      def record_event( # rubocop:disable Metrics/ParameterLists
        name, title, body, body_format, duration,
        opentelemetry_kind: nil, opentelemetry_scope: nil
      )
        start_time = Time.now - (duration / 1_000_000_000.0)
        span = tracer_for(opentelemetry_scope).start_span(
          EVENT_SPAN_PLACEHOLDER_NAME,
          :start_timestamp => start_time,
          :kind => opentelemetry_kind
        )
        write_event_span_name(span, name, title)
        write_event_body_attributes(span, body, body_format)
        # A recorded event has no start hook, so we never measured its
        # allocations. We deliberately set no allocation attribute rather than a
        # misleading zero. Its allocations instead fall into the enclosing
        # event's own count, matching agent mode.
        span.finish
      end

      def set_action(action)
        # The collector reads the action from `appsignal.action_name`, not the
        # span name. Set the name too so the OTel-native trace stays readable;
        # the collector treats the span name as authoritative for display.
        @span.name = action
        @span.set_attribute("appsignal.action_name", action)
        @action = action
        @action_set = true
      end

      def set_namespace(namespace)
        # Only the attribute can change here: SpanKind is fixed at span
        # creation (immutable in OTel) from the initial namespace. A later
        # namespace override updates `appsignal.namespace` but not the kind --
        # the collector uses the attribute for the namespace and the kind only
        # to pick the subtrace root, so this is fine for the rare late change.
        @namespace = namespace
        @span.set_attribute("appsignal.namespace", display_namespace(namespace))
      end

      # Queue start has no OTel-native home, so surface it two ways: an
      # `appsignal.queue_start` event on the root span (per-trace timeline) and,
      # at completion, a `transaction_queue_duration` metric (the aggregate
      # graph). Like the agent, we record the delta and never shift span timing.
      #
      # The queue start time becomes the event's timestamp (events carry their
      # own time), so it is not duplicated as an attribute.
      def set_queue_start(start)
        return unless start && start > QUEUE_START_MIN

        @queue_start = start
        @span.add_event(
          "appsignal.queue_start",
          :timestamp => Time.at(start / 1000.0)
        )
      end

      # Transaction metadata (request path, method, ...) has no dedicated OTel
      # attribute, but it is the same shape as tags and the collector/trace UI
      # already surface `appsignal.tag.*`, so emit metadata as a tag.
      def set_metadata(key, value)
        @span.set_attribute("appsignal.tag.#{key}", value)
      end

      # Sets OpenTelemetry attributes on AppSignal's current span -- the open
      # event span, or the root span when no event is open. This is how an
      # integration describes what it instrumented in OpenTelemetry's own terms,
      # such as `db.system.name` on a database query.
      #
      # Never the OTel current span, which may belong to another
      # instrumentation. Values are coerced to the primitives OTLP accepts.
      def set_attributes(attributes)
        current_span.add_attributes(
          Appsignal::OpenTelemetry::Attributes.format(attributes)
        )
      end

      # The collector keeps the request payload, the function parameters and the
      # query parameters as separate attributes, so each gets its own bucket.
      # Legacy `params` has no channel of its own, so it maps to the request
      # payload (the web/server default), matching how the span kind defaults to
      # `:server`.
      PARAMS_MAPPING = {
        :params => :request_payload,
        :request_payload => :request_payload,
        :function_parameters => :function_parameters,
        :query_parameters => :query_parameters
      }.freeze

      def params_mapping
        PARAMS_MAPPING
      end

      # Routes each sample-data category to the attribute the collector reads.
      # The params arrive on one of three channels: `request_payload` (web),
      # `function_parameters` (jobs) and `query_parameters` (a request's query
      # string), each its own attribute. The other JSON-blob
      # categories (session, custom data) are serialized as JSON; `environment`
      # becomes request-header attributes; tags fan out to `appsignal.tag.*`.
      # Unknown keys pass through as `appsignal.<key>` JSON so nothing is lost.
      # Breadcrumbs never reach here (the backend emits them as span events);
      # causes ride on the exception event (see #set_error).
      def set_sample_data(key, data)
        case key
        when "request_payload"
          @span.set_attribute("appsignal.request.payload", JSON.generate(data))
        when "function_parameters"
          @span.set_attribute("appsignal.function.parameters", JSON.generate(data))
        when "query_parameters"
          @span.set_attribute("appsignal.request.query_parameters", JSON.generate(data))
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
      # raised it. `appsignal.alert_this_error` tells the collector to report it
      # even on a child span.
      #
      # Causes ride on one `appsignal.error_causes` JSON attribute, whose keys
      # match the processor's `ErrorSubCause`. Separate cause events would each
      # become their own incident. Each cause carries only the part of its
      # backtrace that is not shared (see `trim_shared_tail`).
      def set_error(class_name, message, backtrace, causes, _root_cause_missing)
        span = current_span
        error_lines = Array(backtrace)

        attributes = {
          "exception.type" => class_name,
          "exception.message" => message.to_s,
          "exception.stacktrace" => error_lines.join("\n"),
          "appsignal.alert_this_error" => true
        }

        unless causes.empty?
          attributes["appsignal.error_causes"] = JSON.generate(
            causes.map do |cause|
              lines, lines_omitted = trim_shared_tail(Array(cause[:backtrace]), error_lines)

              cause_attributes = {
                "name" => cause[:name],
                "message" => cause[:message],
                "lines" => lines
              }
              cause_attributes["lines_omitted"] = lines_omitted if lines_omitted.positive?
              cause_attributes
            end
          )
        end

        span.add_event("exception", :attributes => attributes)
        # `error.type` is what the semantic conventions read to tell what kind of
        # failure ended the operation. It is an attribute of the span, unlike the
        # `exception.type` above, which is an attribute of the exception event.
        # When a span collects more than one error the last one wins, because a
        # span can only say one thing here.
        span.add_attributes(Appsignal::OpenTelemetry::ErrorType.attributes_for(class_name))
        span.status = ::OpenTelemetry::Trace::Status.error
      end

      # Emits a breadcrumb as an `appsignal.breadcrumb` span event on AppSignal's
      # current span -- the open event span, falling back to the root -- rather
      # than the OTel current span, which may belong to another instrumentation.
      #
      # Emitted immediately, because by completion the event span has finished
      # and the SDK drops events added to an ended span. The breadcrumb's time
      # becomes the event's timestamp, and the metadata Hash is a JSON string,
      # because event attributes are flat.
      #
      # Capped at `BREADCRUMB_LIMIT` per transaction, keeping the first N where
      # agent mode keeps the last N: a streamed event cannot be retracted.
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
        # `teardown` sets `@completed`, so this guard also makes the body
        # idempotent across a double `complete`, and skips it on `discard`.
        unless @completed
          # Aggregate metrics are only emitted for a transaction that set an
          # action to group by. An actionless transaction is never reported in
          # agent mode, so it must contribute to no aggregate here either.
          emit_queue_duration_metric if @action_set
          report_allocation_count
          ignore_subtrace_without_action
        end
        teardown
      end

      # Discarding does not mean "don't send" as it does in agent mode. The root
      # span is still finished and exported, flagged with
      # `appsignal.ignore_subtrace` so the collector drops the whole subtrace.
      # The flag has to be written before the span finishes, because attributes
      # set on an ended span are dropped. Tearing the span down here also
      # detaches the context, so a discarded transaction cannot leave its root
      # span current on the thread.
      def discard
        return if @completed

        @span&.set_attribute("appsignal.ignore_subtrace", true)
        teardown
      end

      # Each error is recorded eagerly as its own `exception` event on the span
      # current when it was added, so a trace holds many errors and the
      # Transaction never duplicates itself -- which is why `duplicate` is left
      # unimplemented (see BaseBackend).
      def supports_multiple_errors?
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
          frame = @event_stack.pop
          ::OpenTelemetry::Context.detach(frame.token)
          frame.span.finish
        end
        ::OpenTelemetry::Context.detach(@context_token) if @context_token
        @span&.finish
      end

      # A transaction that never set an action has nothing to group by, and agent
      # mode does not report one at all. Collector mode cannot represent "no
      # action", so the subtrace is flagged for the collector to drop instead,
      # the same way `discard` does. The flag has to be set before `teardown`
      # finishes the span, because attributes set on an ended span are dropped.
      def ignore_subtrace_without_action
        return if @action_set

        @span&.set_attribute("appsignal.ignore_subtrace", true)
      end

      # Emits the queue duration as a distribution metric in both the
      # per-namespace and per-namespace-and-host series the queue-time graph
      # reads. Nothing downstream fans these out, so emit both ourselves.
      def emit_queue_duration_metric
        return unless @queue_start

        duration_ms = (@start_time.to_f * 1000) - @queue_start
        return if duration_ms.negative?

        namespace = display_namespace(@namespace)
        Appsignal::Metrics::OpenTelemetryBackend.add_distribution_value(
          "transaction_queue_duration", duration_ms, :namespace => namespace
        )
        Appsignal::Metrics::OpenTelemetryBackend.add_distribution_value(
          "transaction_queue_duration", duration_ms,
          :namespace => namespace, :hostname => hostname
        )
      end

      # Sets the transaction's allocation counts on the root span, and, when the
      # transaction has an action to group by, emits the total as a counter
      # metric. The counter is read once so the attributes and the metric share
      # the same value.
      #
      # The root's total is `appsignal.transaction_allocation_count`, named apart
      # from an event's `appsignal.allocation_count` because it resets per
      # transaction: it is the whole that a span's `self_allocation_count` is a
      # part of, including across a distributed trace.
      #
      # The metric is emitted in both the per-namespace and
      # per-namespace-and-action series the allocation graph reads, as a counter,
      # never host-tagged. Nothing downstream fans these out.
      def report_allocation_count
        return unless @allocation_start

        count = Appsignal::Extension.allocation_count - @allocation_start
        return if allocation_count_reversed?(count)

        @span&.set_attribute("appsignal.transaction_allocation_count", count)
        @span&.set_attribute(
          "appsignal.self_allocation_count",
          count - @root_child_allocation_count
        )

        return unless @action_set && count.positive?

        namespace = display_namespace(@namespace)
        Appsignal::Metrics::OpenTelemetryBackend.increment_counter(
          "transaction_allocation_count", count, :namespace => namespace
        )
        Appsignal::Metrics::OpenTelemetryBackend.increment_counter(
          "transaction_allocation_count", count,
          :namespace => namespace, :action => @action
        )
      end

      # Sets a finished event's allocation counts and rolls its full count up to
      # its parent. `appsignal.allocation_count` covers the event's whole
      # subtree; `appsignal.self_allocation_count` excludes its children, so
      # allocations can be attributed to a layer without walking the span tree.
      #
      # Only the immediate parent is updated, because each event's full count
      # already includes its whole subtree. Nothing is set when allocation
      # tracking is off.
      def write_event_allocation_count(frame)
        return unless frame.allocation_start

        full = Appsignal::Extension.allocation_count - frame.allocation_start
        return if allocation_count_reversed?(full)

        self_count = full - frame.child_allocation_count
        # Roll the full count up to the parent so it can compute its own self.
        # A top-level event has no parent event; its full count belongs to the
        # transaction, so credit the root accumulator instead.
        if (parent = @event_stack.last)
          parent.child_allocation_count += full
        else
          @root_child_allocation_count += full
        end
        frame.span.set_attribute("appsignal.allocation_count", full)
        frame.span.set_attribute("appsignal.self_allocation_count", self_count)
      end

      # The allocation counter is thread-local and only ever increases, so a
      # negative delta means the transaction or event finished on a different
      # thread than it started on. The count is then meaningless, so warn and
      # tell the caller to drop it rather than report a wrong value.
      def allocation_count_reversed?(delta)
        return false unless delta.negative?

        Appsignal.internal_logger.warn(
          "Not reporting an allocation count in transaction " \
            "'#{@transaction_id}'. The thread-local allocation counter decreased " \
            "between the start and finish, which happens when the work starts and " \
            "finishes on different threads."
        )
        true
      end

      # The thread's cumulative object allocation count, or nil when allocation
      # tracking is off. Callers snapshot this at a start boundary and subtract
      # it from a later read to get the allocations made in between; a nil
      # snapshot disables allocation reporting for that transaction or event.
      def current_allocation_count
        Appsignal::Extension.allocation_count if allocation_tracking?
      end

      # Allocation tracking runs only when enabled by config and not on JRuby,
      # matching the condition under which `Appsignal.start` installs the
      # allocation event hook that feeds the counter.
      def allocation_tracking?
        return false unless Appsignal.config&.[](:enable_allocation_tracking)

        !Appsignal::System.jruby?
      end

      def hostname
        Appsignal.config&.[](:hostname) || Socket.gethostname
      end

      # Resolve the tracer for an instrumentation scope. `scope` is a
      # `[name, version]` pair supplied by the integration that created the
      # span, or nil. A nil scope, a nil/blank name, or a nil version each fall
      # back to the default AppSignal scope, so every span always carries a
      # scope (the collector drops scope-less spans). The tracer provider caches
      # tracers by `(name, version)`, so this resolves rather than rebuilds.
      def tracer_for(scope)
        name, version = scope
        if name.nil? || name.to_s.empty?
          # A nil scope or one with a blank name is unusable, so fall back to
          # the default scope entirely rather than pairing the default name with
          # a stray version.
          name = TRACER_NAME
          version = Appsignal::VERSION
        else
          version ||= Appsignal::VERSION
        end
        ::OpenTelemetry.tracer_provider.tracer(name, version)
      end

      # The open event span, or the root span when no event is open. Not the OTel
      # current span, which may belong to another instrumentation.
      def current_span
        @event_stack.last&.span || @span
      end

      # Pushes an open event onto the stack, snapshotting the allocation counter
      # so `finish_event` can measure the event's allocations as the delta since.
      def push_event(span, token)
        @event_stack.push(EventFrame.new(span, token, current_allocation_count, 0))
      end

      def placeholder_span_name(namespace)
        "appsignal.transaction #{namespace}"
      end

      # Open the transaction's span, relating it to any incoming trace context
      # by the requested relationship:
      #
      # - `:parent`: parent under the remote span so the transaction continues
      #   the upstream trace.
      # - `:link`: start a fresh trace linked back to the remote span. The
      #   transaction is its own unit of work decoupled from the caller, so it
      #   gets its own trace, with a link recording the causal relationship.
      # - `:both`: parent under the remote span and also link back to it, so the
      #   transaction continues the trace and keeps the explicit link.
      # - `:none`: a plain root span that ignores any incoming context.
      #
      # With no context or an invalid remote span, every relationship falls back
      # to a plain root span, since there is nothing to parent or link to.
      def start_transaction_span(namespace, kind, relationship, opentelemetry_context)
        name = placeholder_span_name(namespace)
        remote = remote_span_context(opentelemetry_context)
        tracer = tracer_for(@scope)

        # With no incoming context (or an invalid remote span) there is nothing
        # to parent or link to, so any relationship is just a plain root span.
        return tracer.start_root_span(name, :kind => kind) unless remote

        # `:parent` and `:both` continue the trace under the remote span;
        # `:link` and `:both` record a link back to it; `:none` does neither.
        parent = opentelemetry_context if [:parent, :both].include?(relationship)
        links = [::OpenTelemetry::Trace::Link.new(remote)] if [:link, :both].include?(relationship)

        if parent
          tracer.start_span(name, :with_parent => parent, :kind => kind, :links => links)
        else
          tracer.start_root_span(name, :kind => kind, :links => links)
        end
      end

      # Returns the given option when it is one of the allowed values, the
      # default when it is nil, or the default with a warning when it is an
      # unknown value. Keeps an unexpected `opentelemetry_kind` from raising
      # inside span creation, and an unexpected `opentelemetry_relationship`
      # from silently dropping the incoming context.
      def validated_option(value, allowed, default, name)
        return default if value.nil?
        return value if allowed.include?(value)

        # A bad value is usually a static mistake passed on every transaction,
        # so warn once per process to avoid flooding the log. Dedup on the
        # option and value, and build the message -- including walking the
        # stack for the caller location -- only when actually warning.
        self.class.warn_once("#{name}: #{value.inspect}") do
          "Unknown #{name} #{value.inspect} passed at #{option_caller_location}, " \
            "falling back to #{default.inspect}. " \
            "Expected one of: #{allowed.map(&:inspect).join(", ")}."
        end
        default
      end

      # The first caller frame outside the gem: where the invalid value was
      # passed to `Transaction.create`, `Appsignal.monitor`, etc. Falls back to
      # the immediate caller if every frame is inside the gem. Only walks the
      # stack when a warning is actually emitted (see `validated_option`).
      def option_caller_location
        frames = caller
        frames.find { |frame| !frame.include?("/lib/appsignal/") } || frames.first
      end

      # The remote parent's SpanContext from an incoming OTel context, or nil
      # when there is no context or the remote span is invalid -- in which case
      # callers fall back to a plain root span.
      def remote_span_context(opentelemetry_context)
        return unless opentelemetry_context

        context = ::OpenTelemetry::Trace.current_span(opentelemetry_context).context
        context if context.valid?
      end

      def display_namespace(namespace)
        DISPLAY_NAMESPACE.fetch(namespace, namespace)
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

      # Returns the leading lines of a cause's backtrace that the reported
      # error's backtrace does not already end with, and how many trailing lines
      # were dropped to get there.
      #
      # A cause shares its trailing frames with the error it led to, and those
      # are already sent in `exception.stacktrace`. Repeating them for every
      # cause makes `appsignal.error_causes` too long for the collector to read.
      #
      # If every line is shared, one is kept, because a cause with no lines
      # leaves the UI nothing to show. That kept line does not count as dropped.
      def trim_shared_tail(cause_lines, error_lines)
        shared = 0
        while shared < cause_lines.length && shared < error_lines.length &&
            cause_lines[-1 - shared] == error_lines[-1 - shared]
          shared += 1
        end

        return [cause_lines, 0] if shared.zero?

        kept = [cause_lines.length - shared, 1].max
        [cause_lines.first(kept), cause_lines.length - kept]
      end

      # The OTel span name is what the collector surfaces as the event's
      # label in the trace UI. The AS::N `name` (e.g. "sql.active_record")
      # always leads the span name so it stays visible. When a formatter
      # supplied a human-readable `title` (e.g. "User Load", "GET
      # https://example.com"), it follows in parentheses, giving
      # "sql.active_record (User Load)". Some integrations pass the event
      # name as the title as well; in that case the name is not repeated.
      def write_event_span_name(span, name, title)
        has_title = title && !title.empty? && title != name
        span.name = has_title ? "#{name} (#{title})" : name
      end

      def write_event_body_attributes(span, body, body_format)
        has_body = !body.to_s.empty?

        if body_format == Appsignal::EventFormatter::SQL_BODY_FORMAT
          # Name the datastore whether or not there is a query to record with it.
          # The semantic conventions require the attribute on every database
          # span, and a SQL event with nothing in its body is still a SQL event.
          span.set_attribute("db.system.name", SQL_DB_SYSTEM)
          span.set_attribute("db.query.text", body) if has_body
        elsif has_body
          span.set_attribute("appsignal.body", body)
        end
      end
    end
  end
end
