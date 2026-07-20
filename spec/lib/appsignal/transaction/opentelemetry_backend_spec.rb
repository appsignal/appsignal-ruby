# frozen_string_literal: true

require "opentelemetry/sdk" if DependencyHelper.opentelemetry_present?

describe Appsignal::Transaction::OpenTelemetryBackend,
  :if => DependencyHelper.opentelemetry_present? do
  let(:span_exporter) { ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer_provider) do
    provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(
      ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(span_exporter)
    )
    provider
  end

  before do
    ::OpenTelemetry.tracer_provider = tracer_provider
    @backends_created = []

    # OTel reports context-balance violations (e.g. DetachError) through its
    # error handler, which by default only logs. Capture them so the after hook
    # can fail the example on an unexpected one -- an accidental imbalance should
    # be a red test, not a silent log. An example that deliberately provokes one
    # sets @expect_otel_errors.
    @otel_errors = []
    @original_otel_error_handler = ::OpenTelemetry.error_handler
    ::OpenTelemetry.error_handler =
      lambda { |exception: nil, message: nil| @otel_errors << [exception, message] }
  end

  # Each `create_backend` call constructs a real backend, which attaches an
  # OTel context on initialize. We track them all here and complete any that
  # the test didn't complete itself, so leftover spans / context attachments
  # don't pollute the next test. Complete in reverse (LIFO) order: the contexts
  # are stacked in creation order, so the last one created must detach first.
  after do
    @backends_created.reverse_each { |backend| backend.complete unless backend._completed? }
    ::OpenTelemetry.error_handler = @original_otel_error_handler
    expect(@otel_errors).to be_empty unless @expect_otel_errors
  end

  def create_backend(namespace = "http_request")
    described_class.new("abc-123", namespace).tap { |b| @backends_created << b }
  end

  def foreign_tracer
    ::OpenTelemetry.tracer_provider.tracer("foreign-instrumentation")
  end

  # Start a foreign span, make it the current OTel context for the block, and
  # detach it afterwards (LIFO). Models another instrumentation's span sitting on
  # top of AppSignal's context.
  def with_foreign_current_span(name = "foreign")
    foreign = foreign_tracer.start_span(name)
    token = ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(foreign))
    yield foreign
  ensure
    ::OpenTelemetry::Context.detach(token)
    foreign.finish
  end

  def finished_span(span)
    span_exporter.finished_spans.find { |s| s.span_id == span.context.span_id }
  end

  def event_names(finished)
    Array(finished&.events).map(&:name)
  end

  describe "#initialize" do
    it "constructs without raising" do
      expect { create_backend }.not_to raise_error
    end

    it "names the span 'appsignal.transaction <namespace>'" do
      create_backend("http_request").complete
      expect(span_exporter.finished_spans.first.name).to eq("appsignal.transaction http_request")
    end

    {
      "http_request" => :server,
      "background_job" => :consumer,
      "action_cable" => :server,
      "some_custom_ns" => :server
    }.each do |namespace, expected_kind|
      it "maps namespace #{namespace.inspect} to SpanKind #{expected_kind.inspect}" do
        create_backend(namespace).complete
        expect(span_exporter.finished_spans.first.kind).to eq(expected_kind)
      end
    end

    context "with an incoming opentelemetry_context" do
      let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
      let(:span_id_hex) { "b7ad6b7169203331" }
      let(:remote_context) do
        # Build the remote parent context directly instead of parsing a
        # `traceparent` through `OpenTelemetry.propagation`. The backend's job
        # is to parent under a context it is handed; extracting one from a
        # carrier is the Rack middleware's job, covered by its own specs.
        # Building it here also keeps this a self-contained unit test: parsing
        # would depend on the global propagator, which is only configured as a
        # side effect of booting the SDK in some other example.
        span_context = ::OpenTelemetry::Trace::SpanContext.new(
          :trace_id => [trace_id_hex].pack("H*"),
          :span_id => [span_id_hex].pack("H*"),
          :trace_flags => ::OpenTelemetry::Trace::TraceFlags.from_byte(0x01),
          :remote => true
        )
        ::OpenTelemetry::Trace.context_with_span(
          ::OpenTelemetry::Trace.non_recording_span(span_context)
        )
      end

      def create_backend_with_context(namespace, context)
        described_class.new("abc-123", namespace, :opentelemetry_context => context)
          .tap { |b| @backends_created << b }
      end

      it "parents a server transaction under the remote span (continues the trace)" do
        backend = create_backend_with_context("http_request", remote_context)
        backend.complete
        root = finished_span(backend.instance_variable_get(:@span))

        expect(root.hex_trace_id).to eq(trace_id_hex)
        expect(root.parent_span_id.unpack1("H*")).to eq(span_id_hex)
        expect(root.kind).to eq(:server)
      end

      it "starts a fresh root trace when no context is given" do
        backend = create_backend("http_request")
        backend.complete
        root = finished_span(backend.instance_variable_get(:@span))

        expect(root.hex_trace_id).not_to eq(trace_id_hex)
        expect(root.parent_span_id).to eq(::OpenTelemetry::Trace::INVALID_SPAN_ID)
      end

      it "links a consumer transaction back to the remote span (starts a new trace)" do
        backend = create_backend_with_context("background_job", remote_context)
        backend.complete
        root = finished_span(backend.instance_variable_get(:@span))

        # A job is its own unit of work: new trace, no parent.
        expect(root.hex_trace_id).not_to eq(trace_id_hex)
        expect(root.parent_span_id).to eq(::OpenTelemetry::Trace::INVALID_SPAN_ID)
        expect(root.kind).to eq(:consumer)

        # ... but linked back to the enqueuing span.
        expect(root.links.size).to eq(1)
        link_context = root.links.first.span_context
        expect(link_context.hex_trace_id).to eq(trace_id_hex)
        expect(link_context.hex_span_id).to eq(span_id_hex)
      end

      it "does not link a consumer transaction when there is no context" do
        backend = create_backend("background_job")
        backend.complete
        root = finished_span(backend.instance_variable_get(:@span))

        expect(root.kind).to eq(:consumer)
        expect(root.links).to be_nil
      end
    end

    it "attaches the new span as the OpenTelemetry current span" do
      backend = create_backend
      expect(::OpenTelemetry::Trace.current_span)
        .to eq(backend.instance_variable_get(:@span))
    end

    it "ignores the ambient OpenTelemetry context and starts a new trace" do
      outer_tracer = ::OpenTelemetry.tracer_provider.tracer("outer")
      outer = outer_tracer.start_span("outer")
      outer_token =
        ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(outer))
      begin
        backend = create_backend
        backend_span = backend.instance_variable_get(:@span)
        expect(backend_span.parent_span_id).to eq(::OpenTelemetry::Trace::INVALID_SPAN_ID)
        expect(backend_span.context.trace_id).not_to eq(outer.context.trace_id)
        # Complete (detach the root context) before detaching the outer token,
        # so the detaches happen in LIFO order.
        backend.complete
      ensure
        ::OpenTelemetry::Context.detach(outer_token)
        outer.finish
      end
    end

    it "restores the previously active OpenTelemetry context on #complete" do
      outer_tracer = ::OpenTelemetry.tracer_provider.tracer("outer")
      outer = outer_tracer.start_span("outer")
      outer_token =
        ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(outer))
      begin
        backend = create_backend
        expect(::OpenTelemetry::Trace.current_span)
          .to eq(backend.instance_variable_get(:@span))

        backend.complete

        expect(::OpenTelemetry::Trace.current_span).to eq(outer)
      ensure
        ::OpenTelemetry::Context.detach(outer_token)
        outer.finish
      end
    end
  end

  describe "write method smoke tests" do
    it "accepts #start_event without raising" do
      expect { create_backend.start_event }.not_to raise_error
    end

    it "accepts #finish_event without raising" do
      expect { create_backend.finish_event("name", "title", "body", 1) }.not_to raise_error
    end

    it "accepts #record_event without raising" do
      expect { create_backend.record_event("name", "title", "body", 1, 1000) }.not_to raise_error
    end

    it "accepts #set_metadata without raising" do
      expect { create_backend.set_metadata("key", "value") }.not_to raise_error
    end

    it "accepts #set_sample_data without raising" do
      expect { create_backend.set_sample_data("params", "anything") }.not_to raise_error
    end
  end

  describe "#start_event with opentelemetry_kind" do
    def event_span_for(category)
      span_exporter.finished_spans.find { |s| s.attributes["appsignal.category"] == category }
    end

    it "creates the event span with the given span kind" do
      backend = create_backend
      backend.start_event(:opentelemetry_kind => :client)
      backend.finish_event("request.net_http", "GET", "", Appsignal::EventFormatter::DEFAULT)
      backend.complete

      expect(event_span_for("request.net_http").kind).to eq(:client)
    end

    it "defaults to an internal span when no kind is given" do
      backend = create_backend
      backend.start_event
      backend.finish_event("sql.query", "title", "", Appsignal::EventFormatter::DEFAULT)
      backend.complete

      expect(event_span_for("sql.query").kind).to eq(:internal)
    end
  end

  describe "#set_queue_start" do
    let(:metrics) { Appsignal::Metrics::OpenTelemetryBackend }

    it "adds an appsignal.queue_start event on the root span at the queue time" do
      allow(metrics).to receive(:add_distribution_value)
      backend = create_backend
      backend.set_queue_start(1_700_000_000_000)
      backend.complete

      event = span_exporter.finished_spans.first.events
        .find { |e| e.name == "appsignal.queue_start" }
      expect(event).not_to be_nil
      expect(event.attributes["appsignal.queue_start"]).to eq(1_700_000_000_000)
    end

    it "emits the queue duration metric in two series on completion" do
      backend = create_backend("background_job")
      backend.set_action("BackgroundJob#perform")
      start_time = backend.instance_variable_get(:@start_time)
      queue_start = ((start_time.to_f * 1000) - 5_000).round

      expect(metrics).to receive(:add_distribution_value).with(
        "transaction_queue_duration", be_within(1_000).of(5_000), :namespace => "background"
      )
      expect(metrics).to receive(:add_distribution_value).with(
        "transaction_queue_duration", be_within(1_000).of(5_000),
        :namespace => "background", :hostname => an_instance_of(String)
      )

      backend.set_queue_start(queue_start)
      backend.complete
    end

    it "does not emit the queue duration metric when no action was set" do
      expect(metrics).to_not receive(:add_distribution_value)
      backend = create_backend("background_job")
      start_time = backend.instance_variable_get(:@start_time)
      queue_start = ((start_time.to_f * 1000) - 5_000).round

      backend.set_queue_start(queue_start)
      backend.complete
    end

    it "ignores values below the epoch-ms floor" do
      expect(metrics).to_not receive(:add_distribution_value)
      backend = create_backend
      backend.set_action("PagesController#show")
      backend.set_queue_start(10)
      backend.complete

      expect(Array(span_exporter.finished_spans.first.events).map(&:name))
        .to_not include("appsignal.queue_start")
    end
  end

  describe "allocation counts" do
    let(:metrics) { Appsignal::Metrics::OpenTelemetryBackend }

    before do
      configure(:options => { :enable_allocation_tracking => true })
      allow(metrics).to receive(:increment_counter)
      # Drive the thread's allocation counter by hand so deltas are exact.
      @allocations = 0
      allow(Appsignal::Extension).to receive(:allocation_count) { @allocations }
    end

    def event_span(category)
      span_exporter.finished_spans.find { |s| s.attributes["appsignal.category"] == category }
    end

    it "sets the transaction total on the root span from the delta since start" do
      @allocations = 100
      backend = create_backend
      backend.set_action("PagesController#show")
      @allocations = 450
      span = backend.instance_variable_get(:@span)
      backend.complete

      attributes = finished_span(span).attributes
      expect(attributes["appsignal.transaction_allocation_count"]).to eq(350)
      # No events, so all of it is the transaction's own self.
      expect(attributes["appsignal.self_allocation_count"]).to eq(350)
    end

    it "sets the root self to the transaction's allocations outside any event" do
      @allocations = 100
      backend = create_backend
      backend.set_action("PagesController#show")
      @allocations = 130 # 30 before the event
      backend.start_event
      @allocations = 175 # 45 inside the event
      backend.finish_event("sql.query", "SQL", "SELECT 1", 0)
      @allocations = 200 # 25 after the event
      span = backend.instance_variable_get(:@span)
      backend.complete

      attributes = finished_span(span).attributes
      # Total 100 -> 200 = 100; the event took 45, so 55 happened outside it.
      expect(attributes["appsignal.transaction_allocation_count"]).to eq(100)
      expect(attributes["appsignal.self_allocation_count"]).to eq(55)
    end

    it "sets a childless event's full and self counts to the delta over the event" do
      @allocations = 100
      backend = create_backend
      @allocations = 130
      backend.start_event
      @allocations = 175
      backend.finish_event("sql.query", "SQL", "SELECT 1", 0)

      attributes = event_span("sql.query").attributes
      expect(attributes["appsignal.allocation_count"]).to eq(45)
      expect(attributes["appsignal.self_allocation_count"]).to eq(45)
    end

    it "excludes a child event's allocations from the parent's self count" do
      @allocations = 100
      backend = create_backend
      @allocations = 110
      backend.start_event # outer
      @allocations = 130
      backend.start_event # inner
      @allocations = 175
      backend.finish_event("sql.query", "SQL", "SELECT 1", 0)
      @allocations = 200
      backend.finish_event("template.render", "Render", "", 0)

      inner = event_span("sql.query").attributes
      outer = event_span("template.render").attributes
      # Inner: full == self == 45 (no children).
      expect(inner["appsignal.allocation_count"]).to eq(45)
      expect(inner["appsignal.self_allocation_count"]).to eq(45)
      # Outer: full 90 covers the inner event; self 45 excludes it.
      expect(outer["appsignal.allocation_count"]).to eq(90)
      expect(outer["appsignal.self_allocation_count"]).to eq(45)
    end

    it "sets no allocation attribute for a recorded event" do
      backend = create_backend
      backend.record_event("sql.query", "SQL", "SELECT 1", 0, 1_000_000)

      attributes = event_span("sql.query").attributes
      expect(attributes).to_not have_key("appsignal.allocation_count")
      expect(attributes).to_not have_key("appsignal.self_allocation_count")
    end

    # Exercises a tree deeper and wider than a single parent-child: three levels
    # of nesting, two siblings, allocations by the parent between its children,
    # and a recorded event whose allocations must fall into the enclosing event.
    # A two-level test can't catch a parent credited with a child's self instead
    # of its full count, because a childless child has self == full; here `e2`
    # has its own child, so the two differ.
    #
    #   transaction root                          (start 0)
    #     e1                                       (start 10)
    #       e2                                     (start 15)
    #         e3   full 15, self 15               (20 -> 35)
    #       e2 own work: 5 before + 7 after e3 -> self 12, full 27
    #       r (recorded): its 8 allocs stay in e1 (42 -> 50)
    #       e4   full 12, self 12                 (58 -> 70)
    #     e1 own: 5 + 8 (r) + 8 + 10 = 31 self, full 70
    #   10 allocs happen before e1 starts, so the transaction total is 80.
    it "computes self correctly across a deep, wide tree with a recorded event" do
      @allocations = 0
      backend = create_backend
      backend.set_action("PagesController#show")

      @allocations = 10
      backend.start_event # e1
      @allocations = 15
      backend.start_event # e2
      @allocations = 20
      backend.start_event # e3
      @allocations = 35
      backend.finish_event("e3", "e3", "", 0)
      @allocations = 42
      backend.finish_event("e2", "e2", "", 0)
      @allocations = 50 # e1's own allocations, recorded below (must not be excluded)
      backend.record_event("r", "r", "", 0, 1_000_000)
      @allocations = 58
      backend.start_event # e4
      @allocations = 70
      backend.finish_event("e4", "e4", "", 0)
      @allocations = 80
      backend.finish_event("e1", "e1", "", 0)

      span = backend.instance_variable_get(:@span)
      backend.complete

      # [full, self] for an event span, by category name.
      counts = lambda do |category|
        attributes = event_span(category).attributes
        [attributes["appsignal.allocation_count"], attributes["appsignal.self_allocation_count"]]
      end

      expect(counts.call("e3")).to eq([15, 15])
      expect(counts.call("e2")).to eq([27, 12])
      expect(counts.call("e4")).to eq([12, 12])
      # e1's self (31) includes the recorded event's 8 allocations and excludes
      # both e2 (27, which itself includes e3) and e4 (12).
      expect(counts.call("e1")).to eq([70, 31])

      expect(event_span("r").attributes).to_not have_key("appsignal.allocation_count")
      root = finished_span(span).attributes
      # Transaction total spans everything, including the 10 allocations before e1.
      expect(root["appsignal.transaction_allocation_count"]).to eq(80)
      # Root self excludes e1 (the only top-level event, full 70), leaving the 10
      # allocations that happened before any event started.
      expect(root["appsignal.self_allocation_count"]).to eq(10)
    end

    it "emits the allocation count metric in two series when an action was set" do
      @allocations = 100
      backend = create_backend
      backend.set_action("PagesController#show")
      @allocations = 300

      expect(metrics).to receive(:increment_counter).with(
        "transaction_allocation_count", 200, :namespace => "web"
      )
      expect(metrics).to receive(:increment_counter).with(
        "transaction_allocation_count", 200,
        :namespace => "web", :action => "PagesController#show"
      )

      backend.complete
    end

    it "does not emit the allocation count metric when no action was set" do
      @allocations = 100
      backend = create_backend
      @allocations = 300
      expect(metrics).to_not receive(:increment_counter)

      backend.complete
    end

    it "does not emit the allocation count metric when the delta is zero" do
      @allocations = 100
      backend = create_backend
      backend.set_action("PagesController#show")
      expect(metrics).to_not receive(:increment_counter)

      backend.complete
    end

    it "does not emit the allocation count metric when discarded" do
      @allocations = 100
      backend = create_backend
      backend.set_action("PagesController#show")
      @allocations = 300
      expect(metrics).to_not receive(:increment_counter)

      backend.discard
    end

    # The counter is thread-local and only climbs, so a lower value at finish
    # than at start means the work moved threads. The delta is meaningless.
    it "drops an event's allocation counts and warns when the counter reversed" do
      @allocations = 200
      backend = create_backend
      @allocations = 250
      backend.start_event
      @allocations = 100 # finished on another thread: counter went backwards
      logs = capture_logs { backend.finish_event("sql.query", "SQL", "SELECT 1", 0) }

      attributes = event_span("sql.query").attributes
      expect(attributes).to_not have_key("appsignal.allocation_count")
      expect(attributes).to_not have_key("appsignal.self_allocation_count")
      expect(logs).to include("allocation counter decreased")
    end

    it "drops the transaction allocation counts and warns when the counter reversed" do
      @allocations = 500
      backend = create_backend
      backend.set_action("PagesController#show")
      @allocations = 100 # finished on another thread: counter went backwards
      span = backend.instance_variable_get(:@span)
      expect(metrics).to_not receive(:increment_counter)

      logs = capture_logs { backend.complete }

      attributes = finished_span(span).attributes
      expect(attributes).to_not have_key("appsignal.transaction_allocation_count")
      expect(attributes).to_not have_key("appsignal.self_allocation_count")
      expect(logs).to include("allocation counter decreased")
    end

    context "when allocation tracking is disabled" do
      before { configure(:options => { :enable_allocation_tracking => false }) }

      it "sets no allocation attributes and emits no metric" do
        @allocations = 100
        backend = create_backend
        backend.set_action("PagesController#show")
        @allocations = 300
        span = backend.instance_variable_get(:@span)
        expect(metrics).to_not receive(:increment_counter)

        backend.complete

        expect(finished_span(span).attributes)
          .to_not have_key("appsignal.transaction_allocation_count")
      end
    end
  end

  describe "#set_action" do
    it "renames the root span to the action" do
      backend = create_backend
      backend.set_action("PagesController#show")
      backend.complete

      expect(span_exporter.finished_spans.first.name).to eq("PagesController#show")
    end

    it "sets the appsignal.action_name attribute on the root span" do
      backend = create_backend
      backend.set_action("PagesController#show")
      backend.complete

      expect(span_exporter.finished_spans.first.attributes["appsignal.action_name"])
        .to eq("PagesController#show")
    end
  end

  describe "appsignal.namespace attribute" do
    # The backend converts the internal namespaces to the values the collector
    # expects; everything else passes through.
    {
      "http_request" => "web",
      "background_job" => "background",
      "action_cable" => "action_cable",
      "custom" => "custom"
    }.each do |namespace, expected|
      it "maps the constructor namespace #{namespace.inspect} to #{expected.inspect}" do
        create_backend(namespace).complete

        expect(span_exporter.finished_spans.first.attributes["appsignal.namespace"])
          .to eq(expected)
      end
    end

    describe "#set_namespace" do
      it "overwrites the appsignal.namespace attribute" do
        backend = create_backend("http_request")
        backend.set_namespace("custom")
        backend.complete

        expect(span_exporter.finished_spans.first.attributes["appsignal.namespace"])
          .to eq("custom")
      end

      it "converts the overriding namespace to its canonical value" do
        backend = create_backend("custom")
        backend.set_namespace("background_job")
        backend.complete

        expect(span_exporter.finished_spans.first.attributes["appsignal.namespace"])
          .to eq("background")
      end

      it "does not change the span kind (fixed at creation)" do
        backend = create_backend("http_request")
        backend.set_namespace("background_job")
        backend.complete

        expect(span_exporter.finished_spans.first.kind).to eq(:server)
      end
    end
  end

  describe "#set_error" do
    def exception_event(backend)
      backend.complete
      backend_span_id = backend.instance_variable_get(:@span).context.span_id
      root = span_exporter.finished_spans.find { |s| s.span_id == backend_span_id }
      root.events.find { |e| e.name == "exception" }
    end

    it "records an exception span-event on the root span" do
      backend = create_backend
      backend.set_error("RuntimeError", "boom", ["line 1", "line 2"], [], false)

      event = exception_event(backend)
      expect(event).not_to be_nil
      expect(event.attributes["exception.type"]).to eq("RuntimeError")
      expect(event.attributes["exception.message"]).to eq("boom")
      expect(event.attributes["exception.stacktrace"]).to eq("line 1\nline 2")
    end

    it "sets the span status to error" do
      backend = create_backend
      backend.set_error("RuntimeError", "boom", ["line 1"], [], false)
      backend.complete

      backend_span_id = backend.instance_variable_get(:@span).context.span_id
      root = span_exporter.finished_spans.find { |s| s.span_id == backend_span_id }
      expect(root.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
    end

    it "omits exception.stacktrace content when there is no backtrace" do
      backend = create_backend
      backend.set_error("RuntimeError", "boom", nil, [], false)

      expect(exception_event(backend).attributes["exception.stacktrace"]).to eq("")
    end

    it "emits causes as an appsignal.error_causes JSON attribute matching ErrorSubCause" do
      backend = create_backend
      causes = [
        { :name => "ArgumentError", :message => "bad arg", :backtrace => ["cause 1", "cause 2"] },
        { :name => "KeyError", :message => "missing", :backtrace => ["cause 3"] }
      ]
      backend.set_error("RuntimeError", "boom", ["line 1"], causes, false)

      parsed = JSON.parse(exception_event(backend).attributes["appsignal.error_causes"])
      expect(parsed).to eq(
        [
          { "name" => "ArgumentError", "message" => "bad arg", "lines" => ["cause 1", "cause 2"] },
          { "name" => "KeyError", "message" => "missing", "lines" => ["cause 3"] }
        ]
      )
    end

    it "defaults a cause's lines to an empty Array when it has no backtrace" do
      backend = create_backend
      backend.set_error(
        "RuntimeError", "boom", ["line 1"],
        [{ :name => "ArgumentError", :message => "bad arg", :backtrace => nil }],
        false
      )

      parsed = JSON.parse(exception_event(backend).attributes["appsignal.error_causes"])
      expect(parsed).to eq([{ "name" => "ArgumentError", "message" => "bad arg", "lines" => [] }])
    end

    it "does not set appsignal.error_causes when there are no causes" do
      backend = create_backend
      backend.set_error("RuntimeError", "boom", ["line 1"], [], false)

      expect(exception_event(backend).attributes).not_to have_key("appsignal.error_causes")
    end

    it "flags the error for the collector and lets it compute the digest" do
      backend = create_backend
      backend.set_error("RuntimeError", "boom", ["line 1"], [], false)

      attributes = exception_event(backend).attributes
      # The gem flags the exception so the collector reports it even on a
      # non-root span; the collector computes the digest itself.
      expect(attributes["appsignal.alert_this_error"]).to eq(true)
      expect(attributes).not_to have_key("appsignal.error_digest")
    end

    it "records the exception on the span that is current when called" do
      backend = create_backend
      backend.start_event
      backend.set_error("RuntimeError", "boom", ["line 1"], [], false)
      backend.finish_event("sql.query", "title", "body", Appsignal::EventFormatter::DEFAULT)
      backend.complete

      event_span = span_exporter.finished_spans
        .find { |s| s.attributes["appsignal.category"] == "sql.query" }
      backend_span_id = backend.instance_variable_get(:@span).context.span_id
      root = span_exporter.finished_spans.find { |s| s.span_id == backend_span_id }

      expect(event_span.events.map(&:name)).to include("exception")
      expect(Array(root.events).map(&:name)).not_to include("exception")
    end

    it "records one exception event per call (multiple errors on one span)" do
      backend = create_backend
      backend.set_error("RuntimeError", "first", ["line 1"], [], false)
      backend.set_error("ArgumentError", "second", ["line 2"], [], false)
      backend.complete

      backend_span_id = backend.instance_variable_get(:@span).context.span_id
      root = span_exporter.finished_spans.find { |s| s.span_id == backend_span_id }
      events = root.events.select { |e| e.name == "exception" }
      expect(events.map { |e| e.attributes["exception.type"] })
        .to eq(["RuntimeError", "ArgumentError"])
      expect(events.map { |e| e.attributes["exception.message"] }).to eq(["first", "second"])
    end
  end

  describe "#supports_multiple_errors?" do
    it "returns true (multiple exception events on one span)" do
      expect(create_backend.supports_multiple_errors?).to eq(true)
    end
  end

  describe "#finish" do
    it "returns true so Transaction#complete runs the sample_data path" do
      expect(create_backend.finish).to eq(true)
    end
  end

  describe "#complete" do
    it "finishes the OTel span" do
      backend = create_backend
      span = backend.instance_variable_get(:@span)
      backend.complete

      # `finished_spans` returns immutable `SpanData` structs, not the
      # mutable `Span` objects we hold a reference to — compare by span_id.
      expect(span_exporter.finished_spans.map(&:span_id)).to include(span.context.span_id)
    end

    it "detaches the OTel context (current_span back to INVALID)" do
      backend = create_backend
      expect(::OpenTelemetry::Trace.current_span).not_to eq(::OpenTelemetry::Trace::Span::INVALID)

      backend.complete

      expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)
    end

    it "toggles _completed? from false to true" do
      backend = create_backend
      expect(backend._completed?).to eq(false)

      backend.complete

      expect(backend._completed?).to eq(true)
    end

    context "when no action was set" do
      it "flags the subtrace as ignored so the collector drops the placeholder-named root" do
        backend = create_backend
        span = backend.instance_variable_get(:@span)
        backend.complete

        finished = finished_span(span)
        expect(finished.name).to eq("appsignal.transaction http_request")
        expect(finished.attributes["appsignal.ignore_subtrace"]).to be(true)
      end
    end

    context "when an action was set" do
      it "does not flag the subtrace as ignored" do
        backend = create_backend
        backend.set_action("PagesController#show")
        span = backend.instance_variable_get(:@span)
        backend.complete

        finished = finished_span(span)
        expect(finished.attributes["appsignal.action_name"]).to eq("PagesController#show")
        expect(finished.attributes).to_not have_key("appsignal.ignore_subtrace")
      end
    end
  end

  describe "#discard" do
    it "sets appsignal.ignore_subtrace = true on the root span" do
      backend = create_backend
      span = backend.instance_variable_get(:@span)
      backend.discard

      finished = span_exporter.finished_spans.find { |s| s.span_id == span.context.span_id }
      expect(finished.attributes["appsignal.ignore_subtrace"]).to be(true)
    end

    it "finishes the OTel span" do
      backend = create_backend
      span = backend.instance_variable_get(:@span)
      backend.discard

      expect(span_exporter.finished_spans.map(&:span_id)).to include(span.context.span_id)
    end

    it "detaches the OTel context (current_span back to INVALID)" do
      backend = create_backend
      expect(::OpenTelemetry::Trace.current_span).not_to eq(::OpenTelemetry::Trace::Span::INVALID)

      backend.discard

      expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)
    end

    it "toggles _completed? from false to true" do
      backend = create_backend
      expect(backend._completed?).to eq(false)

      backend.discard

      expect(backend._completed?).to eq(true)
    end

    it "is idempotent" do
      backend = create_backend
      backend.discard

      expect { backend.discard }.not_to raise_error
    end
  end

  describe "#duplicate" do
    # Collector mode records every error eagerly on one trace, so the Transaction
    # never duplicates the backend. Duplication is agent-only.
    it "raises NotImplementedError" do
      expect { create_backend.duplicate("new-id") }.to raise_error(NotImplementedError)
    end
  end

  describe "#to_json" do
    it 'returns "{}" so Transaction#to_h yields an empty Hash' do
      backend = create_backend
      expect(backend.to_json).to eq("{}")
      expect(JSON.parse(backend.to_json)).to eq({})
    end
  end

  describe "#queue_start" do
    it "returns nil (set_queue_start is a no-op for now)" do
      backend = create_backend
      backend.set_queue_start(123_456)
      expect(backend.queue_start).to be_nil
    end
  end

  # Smoke test: a Transaction backed by an OpenTelemetryBackend exercises
  # every public API path without raising, and emits exactly one OTel root
  # span on completion. The lifecycle behavior (kind, name, context attach)
  # is covered above; this test mostly guards that no-op methods don't
  # accidentally start crashing when called from the Transaction.
  describe "Transaction backed by this backend (collector-mode shape)" do
    before { start_agent }

    def new_transaction_with_otel_backend(namespace = Appsignal::Transaction::HTTP_REQUEST)
      backend = described_class.new("abc-123", namespace)
      @backends_created << backend
      Appsignal::Transaction.new(namespace, :backend => backend)
    end

    it "does not raise across the create -> events -> set_action -> complete flow" do
      expect do
        transaction = new_transaction_with_otel_backend
        transaction.set_action("MyController#index")
        transaction.set_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        transaction.set_queue_start(1_000_000)
        transaction.set_metadata("foo", "bar")
        transaction.start_event
        transaction.finish_event("sql.query", "title", "SELECT 1", 1)
        transaction.add_tags(:tag => "value")
        transaction.add_error(RuntimeError.new("boom"))
        transaction.complete
        transaction.to_h
      end.not_to raise_error
    end

    it "produces an empty Hash from #to_h (to_json returns {})" do
      transaction = new_transaction_with_otel_backend
      transaction.start_event
      transaction.finish_event("event", "title", "body", 1)
      transaction.complete

      expect(transaction.to_h).to eq({})
    end

    it "emits a root span plus a child event span on completion" do
      transaction = new_transaction_with_otel_backend
      transaction.start_event
      transaction.finish_event("event", "title", "body", Appsignal::EventFormatter::DEFAULT)
      transaction.complete

      expect(span_exporter.finished_spans.size).to eq(2)
      kinds = span_exporter.finished_spans.map(&:kind)
      expect(kinds).to include(:server)
      expect(kinds).to include(:internal)
    end
  end

  describe "event stack" do
    describe "#start_event" do
      it "opens a child span and attaches it as the current OTel context" do
        backend = create_backend
        root_span = backend.instance_variable_get(:@span)

        backend.start_event

        current = ::OpenTelemetry::Trace.current_span
        expect(current).not_to eq(root_span)
        expect(current.context.trace_id).to eq(root_span.context.trace_id)

        stack = backend.instance_variable_get(:@event_stack)
        expect(stack.size).to eq(1)
        expect(stack.first.first).to eq(current)
      end
    end

    describe "#finish_event" do
      it "pops the stack, names the span after the title, finishes it, and detaches the context" do
        backend = create_backend
        root_span = backend.instance_variable_get(:@span)

        backend.start_event
        backend.finish_event("custom.event", "Title", "Body",
          Appsignal::EventFormatter::DEFAULT)

        expect(backend.instance_variable_get(:@event_stack)).to be_empty
        expect(::OpenTelemetry::Trace.current_span).to eq(root_span)

        event_span = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "custom.event" }
        expect(event_span).not_to be_nil
        # The human-readable title becomes the span name; the event name
        # rides along in appsignal.category.
        expect(event_span.name).to eq("Title")
        expect(event_span.attributes["appsignal.category"]).to eq("custom.event")
        expect(event_span.attributes["appsignal.body"]).to eq("Body")
        expect(event_span.attributes).not_to have_key("appsignal.title")
      end

      it "does nothing if the event stack is empty (unpaired finish_event)" do
        backend = create_backend
        expect do
          backend.finish_event("custom.event", "T", "B",
            Appsignal::EventFormatter::DEFAULT)
        end.not_to raise_error
      end
    end

    describe "#record_event" do
      it "creates a child span with the event name and a backdated start_timestamp" do
        backend = create_backend
        duration_ns = 1_000_000_000 # 1 second
        backend.record_event("custom.event", "T", "B",
          Appsignal::EventFormatter::DEFAULT, duration_ns)

        span = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "custom.event" }
        expect(span).not_to be_nil
        expect(span.name).to eq("T")
        observed = span.end_timestamp - span.start_timestamp
        # Allow a small slack for clock jitter and the time elapsed
        # between computing start_time and calling finish.
        expect(observed).to be_within(50_000_000).of(duration_ns)
      end

      it "does NOT push onto the event stack" do
        backend = create_backend
        backend.record_event("custom.event", nil, nil,
          Appsignal::EventFormatter::DEFAULT, 1_000)
        expect(backend.instance_variable_get(:@event_stack)).to be_empty
      end
    end

    describe "nested events" do
      it "produces a properly nested span tree" do
        backend = create_backend
        root_span = backend.instance_variable_get(:@span)

        backend.start_event
        outer_span = backend.instance_variable_get(:@event_stack).last.first
        backend.start_event
        inner_span = backend.instance_variable_get(:@event_stack).last.first

        backend.finish_event("inner.event", nil, nil,
          Appsignal::EventFormatter::DEFAULT)
        backend.finish_event("outer.event", nil, nil,
          Appsignal::EventFormatter::DEFAULT)

        inner = span_exporter.finished_spans.find { |s| s.name == "inner.event" }
        outer = span_exporter.finished_spans.find { |s| s.name == "outer.event" }

        expect(inner.span_id).to eq(inner_span.context.span_id)
        expect(outer.span_id).to eq(outer_span.context.span_id)
        expect(inner.parent_span_id).to eq(outer_span.context.span_id)
        expect(outer.parent_span_id).to eq(root_span.context.span_id)
      end
    end

    describe "attribute mapping" do
      it "writes db.query.text + db.system.name for SQL bodies (not appsignal.body)" do
        backend = create_backend
        backend.start_event
        backend.finish_event("sql.query", "Q", "SELECT 1",
          Appsignal::EventFormatter::SQL_BODY_FORMAT)

        attrs = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "sql.query" }.attributes
        expect(attrs["db.query.text"]).to eq("SELECT 1")
        expect(attrs["db.system.name"]).to eq("other_sql")
        expect(attrs).not_to have_key("appsignal.body")
      end

      it "writes appsignal.body for default bodies (no db.* attributes)" do
        backend = create_backend
        backend.start_event
        backend.finish_event("custom", "T", "Body",
          Appsignal::EventFormatter::DEFAULT)

        attrs = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "custom" }.attributes
        expect(attrs["appsignal.body"]).to eq("Body")
        expect(attrs).not_to have_key("db.query.text")
        expect(attrs).not_to have_key("db.system.name")
      end

      it "omits the body attribute entirely when body is empty or nil" do
        backend = create_backend
        backend.start_event
        backend.finish_event("no.body", "T", nil,
          Appsignal::EventFormatter::DEFAULT)
        backend.start_event
        backend.finish_event("empty.body", "T", "",
          Appsignal::EventFormatter::DEFAULT)

        no_body = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "no.body" }
        empty_body = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "empty.body" }
        expect(no_body.attributes).not_to have_key("appsignal.body")
        expect(no_body.attributes).not_to have_key("db.query.text")
        expect(empty_body.attributes).not_to have_key("appsignal.body")
        expect(empty_body.attributes).not_to have_key("db.query.text")
      end

      it "falls back to the event name as the span name when title is empty or nil" do
        backend = create_backend
        backend.start_event
        backend.finish_event("no.title", nil, "Body",
          Appsignal::EventFormatter::DEFAULT)
        backend.start_event
        backend.finish_event("empty.title", "", "Body",
          Appsignal::EventFormatter::DEFAULT)

        no_title = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "no.title" }
        empty_title = span_exporter.finished_spans
          .find { |s| s.attributes["appsignal.category"] == "empty.title" }
        # With no usable title, the span name is the event name itself.
        expect(no_title.name).to eq("no.title")
        expect(empty_title.name).to eq("empty.title")
        expect(no_title.attributes).not_to have_key("appsignal.title")
        expect(empty_title.attributes).not_to have_key("appsignal.title")
      end
    end

    describe "#complete with unfinished event spans" do
      it "drains the event stack without raising, finishing each span with the placeholder name" do
        backend = create_backend
        backend.start_event
        backend.start_event

        expect { backend.complete }.not_to raise_error
        expect(backend.instance_variable_get(:@event_stack)).to be_empty

        # Both drained spans keep the placeholder name; root span keeps its own.
        names = span_exporter.finished_spans.map(&:name)
        expect(names.count("appsignal.event")).to eq(2)
      end
    end
  end

  describe "#add_breadcrumb" do
    def breadcrumb(overrides = {})
      {
        :time => 1_700_000_000,
        :category => "network",
        :action => "GET /",
        :message => "ok",
        :metadata => { "code" => "200" }
      }.merge(overrides)
    end

    it "emits an appsignal.breadcrumb event with the breadcrumb's fields and time" do
      backend = create_backend
      backend.add_breadcrumb(breadcrumb)
      backend.complete

      event = finished_span(backend.instance_variable_get(:@span)).events
        .find { |e| e.name == "appsignal.breadcrumb" }
      expect(event.attributes["category"]).to eq("network")
      expect(event.attributes["action"]).to eq("GET /")
      expect(event.attributes["message"]).to eq("ok")
      expect(JSON.parse(event.attributes["metadata"])).to eq("code" => "200")
      expect(event.timestamp).to eq((Time.at(1_700_000_000).to_r * 1_000_000_000).to_i)
    end

    it "lands on the open event span when one is open" do
      backend = create_backend
      backend.start_event
      event_span = backend.instance_variable_get(:@event_stack).last.first
      backend.add_breadcrumb(breadcrumb)
      backend.finish_event("custom", "T", "B", Appsignal::EventFormatter::DEFAULT)
      backend.complete

      expect(event_names(finished_span(event_span))).to include("appsignal.breadcrumb")
    end

    it "caps at BREADCRUMB_LIMIT, keeping the first ones added" do
      backend = create_backend
      limit = Appsignal::Transaction::BREADCRUMB_LIMIT
      (limit + 5).times { |i| backend.add_breadcrumb(breadcrumb(:action => "act-#{i}")) }
      backend.complete

      crumbs = finished_span(backend.instance_variable_get(:@span)).events
        .select { |e| e.name == "appsignal.breadcrumb" }
      expect(crumbs.size).to eq(limit)
      expect(crumbs.first.attributes["action"]).to eq("act-0")
      expect(crumbs.last.attributes["action"]).to eq("act-#{limit - 1}")
    end
  end

  # AppSignal writes to the OpenTelemetry SDK but does not read its global
  # current span to decide where its own data goes: errors and breadcrumbs land
  # on AppSignal's own span (the open event span, or the root), never on a
  # foreign span that happens to be current. Parenting is the one thing that
  # does follow the global context, so foreign and AppSignal spans nest under
  # each other.
  describe "interop with foreign OpenTelemetry spans" do
    describe "AppSignal data lands on AppSignal's own spans" do
      it "records an error on the root span, not a foreign current span" do
        backend = create_backend
        foreign = nil
        with_foreign_current_span do |f|
          foreign = f
          backend.set_error("RuntimeError", "boom", ["line 1"], [], false)
        end
        backend.complete

        expect(event_names(finished_span(backend.instance_variable_get(:@span))))
          .to include("exception")
        expect(event_names(finished_span(foreign))).not_to include("exception")
      end

      it "records an error on the open event span, not a foreign current span" do
        backend = create_backend
        backend.start_event
        event_span = backend.instance_variable_get(:@event_stack).last.first
        foreign = nil
        with_foreign_current_span do |f|
          foreign = f
          backend.set_error("RuntimeError", "boom", ["line 1"], [], false)
        end
        backend.finish_event("sql.query", "title", "body", Appsignal::EventFormatter::DEFAULT)
        backend.complete

        expect(event_names(finished_span(event_span))).to include("exception")
        expect(event_names(finished_span(foreign))).not_to include("exception")
        expect(event_names(finished_span(backend.instance_variable_get(:@span))))
          .not_to include("exception")
      end

      it "records a breadcrumb on the root span, not a foreign current span" do
        backend = create_backend
        foreign = nil
        with_foreign_current_span do |f|
          foreign = f
          backend.add_breadcrumb(
            :time => 1_700_000_000, :category => "c", :action => "a",
            :message => "m", :metadata => {}
          )
        end
        backend.complete

        expect(event_names(finished_span(backend.instance_variable_get(:@span))))
          .to include("appsignal.breadcrumb")
        expect(event_names(finished_span(foreign))).not_to include("appsignal.breadcrumb")
      end
    end

    describe "tree shape (parenting follows the global context)" do
      it "parents a foreign span under the open AppSignal event span" do
        backend = create_backend
        backend.start_event
        event_span = backend.instance_variable_get(:@event_stack).last.first

        foreign = foreign_tracer.start_span("foreign")
        foreign.finish

        backend.finish_event("e", "t", "b", Appsignal::EventFormatter::DEFAULT)
        backend.complete

        expect(finished_span(foreign).parent_span_id).to eq(event_span.context.span_id)
      end

      it "parents a foreign span under the root span when no event is open" do
        backend = create_backend
        root = backend.instance_variable_get(:@span)

        foreign = foreign_tracer.start_span("foreign")
        foreign.finish
        backend.complete

        expect(finished_span(foreign).parent_span_id).to eq(root.context.span_id)
      end

      it "parents an AppSignal event span under a foreign current span" do
        backend = create_backend
        event_span = nil
        foreign_id = nil
        with_foreign_current_span do |foreign|
          foreign_id = foreign.context.span_id
          backend.start_event
          event_span = backend.instance_variable_get(:@event_stack).last.first
          backend.finish_event("e", "t", "b", Appsignal::EventFormatter::DEFAULT)
        end
        backend.complete

        expect(finished_span(event_span).parent_span_id).to eq(foreign_id)
      end
    end

    describe "context lifecycle" do
      it "unwinds cleanly when a foreign span attaches and detaches inside an event" do
        backend = create_backend
        root = backend.instance_variable_get(:@span)
        backend.start_event

        with_foreign_current_span { nil }

        backend.finish_event("e", "t", "b", Appsignal::EventFormatter::DEFAULT)
        expect(::OpenTelemetry::Trace.current_span).to eq(root)
        expect(backend.instance_variable_get(:@event_stack)).to be_empty

        backend.complete
        expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)
        # The after hook asserts no OTel context error was recorded.
      end

      it "does not defend against a co-resident context leak (characterization)" do
        # If another instrumentation attaches a context and never detaches it,
        # AppSignal's own detach pops that leaked frame instead of its own and
        # OTel signals a DetachError. AppSignal does not try to recover. This
        # records the current behaviour; it is not a guarantee.
        @expect_otel_errors = true

        backend = create_backend
        backend.start_event
        leaked = foreign_tracer.start_span("leaky")
        ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(leaked))

        backend.finish_event("e", "t", "b", Appsignal::EventFormatter::DEFAULT)

        expect(@otel_errors.map(&:first))
          .to include(an_instance_of(::OpenTelemetry::Context::DetachError))

        backend.complete
        leaked.finish
        # Clear the deliberately leaked frame so it can't pollute later examples.
        ::OpenTelemetry::Context.clear
      end
    end
  end
end
