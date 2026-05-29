# frozen_string_literal: true

# Unit-integration tests for `Appsignal::Transaction`. These exercise the
# Transaction object in realistic flows (creation -> current -> complete ->
# clear thread-local) in both agent mode and collector mode, side by side.
#
# The shared examples cover the mode-agnostic structural behavior: the new
# Transaction lives in the thread-local, it carries the namespace and id we
# passed, completion toggles the completed? flag, and `complete_current!`
# clears the thread-local. Each mode then adds its own telemetry-specific
# assertions on top — `to_h` matchers in agent mode, OpenTelemetry span
# exporter assertions in collector mode.
#
# See [[unit-integration-test-rhythm]].

RSpec.shared_examples "transaction events (mode-agnostic)" do
  it "Transaction#instrument returns the block's value" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)

    result = transaction.instrument("sql.active_record", "Query", "SELECT 1",
      Appsignal::EventFormatter::SQL_BODY_FORMAT) { 42 }

    expect(result).to eq(42)
  end

  it "Transaction#instrument re-raises a block exception" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)

    expect do
      transaction.instrument("x.y", nil, nil, Appsignal::EventFormatter::DEFAULT) { raise "boom" }
    end.to raise_error("boom")
  end
end

RSpec.shared_examples "transaction lifecycle (mode-agnostic)" do
  it "creates a Transaction with the given namespace and a generated id" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)

    expect(transaction).to be_a(Appsignal::Transaction)
    expect(transaction.transaction_id).to be_a(String)
    expect(transaction.transaction_id).not_to be_empty
    expect(transaction.namespace).to eq(Appsignal::Transaction::HTTP_REQUEST)
  end

  it "puts the created transaction in Appsignal::Transaction.current" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)

    expect(Appsignal::Transaction.current).to eq(transaction)
    expect(Appsignal::Transaction.current?).to be(true)
  end

  it "marks the transaction completed after #complete" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
    transaction.complete

    expect(transaction.completed?).to be(true)
  end

  it "clears the thread-local on complete_current!" do
    Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
    Appsignal::Transaction.complete_current!

    expect(Appsignal::Transaction.current).to be_a(Appsignal::Transaction::NilTransaction)
    expect(Appsignal::Transaction.current?).to be(false)
  end
end

describe "Appsignal::Transaction lifecycle in agent mode" do
  before { start_agent }

  include_examples "transaction lifecycle (mode-agnostic)"
  include_examples "transaction events (mode-agnostic)"

  it "serializes id, namespace and completed? via to_h after completion" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
    keep_transactions { Appsignal::Transaction.complete_current! }

    expect(transaction).to have_id(transaction.transaction_id)
    expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
    expect(transaction).to be_completed
  end

  describe "events recorded into to_h" do
    it "records an instrumented event with name, title, body and SQL body_format" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      keep_transactions do
        transaction.instrument("sql.active_record", "Query", "SELECT 1",
          Appsignal::EventFormatter::SQL_BODY_FORMAT) { nil }
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to include_event(
        "name" => "sql.active_record",
        "title" => "Query",
        "body" => "SELECT 1",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
      )
    end

    it "records an instrumented event with the default body_format" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      keep_transactions do
        transaction.instrument("custom.event", "Title", "Body",
          Appsignal::EventFormatter::DEFAULT) { nil }
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to include_event(
        "name" => "custom.event",
        "title" => "Title",
        "body" => "Body",
        "body_format" => Appsignal::EventFormatter::DEFAULT
      )
    end

    it "records a record_event call with the given duration" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      keep_transactions do
        transaction.record_event("custom.event", "T", "B", 1_000_000_000,
          Appsignal::EventFormatter::DEFAULT)
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to include_event(
        "name" => "custom.event",
        "title" => "T",
        "body" => "B"
      )
    end

    it "records both events for nested instrument calls" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      keep_transactions do
        transaction.instrument("outer.event", "Outer", "outer body",
          Appsignal::EventFormatter::DEFAULT) do
          transaction.instrument("inner.event", "Inner", "inner body",
            Appsignal::EventFormatter::DEFAULT) { nil }
        end
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to include_event(
        "name" => "outer.event", "title" => "Outer", "body" => "outer body"
      )
      expect(transaction).to include_event(
        "name" => "inner.event", "title" => "Inner", "body" => "inner body"
      )
    end
  end
end

describe "Appsignal::Transaction lifecycle in collector mode" do
  require "opentelemetry/sdk"

  let(:span_exporter) { ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer_provider) do
    provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(
      ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(span_exporter)
    )
    provider
  end

  before do
    start_agent(:options => { :collector_endpoint => "http://127.0.0.1:9090" })
    # Replace the tracer provider booted by Appsignal::OpenTelemetry.configure
    # with one whose processor pushes into our in-memory exporter, so we can
    # inspect spans inside the test instead of trying to flush them out over
    # OTLP/HTTP.
    ::OpenTelemetry.tracer_provider = tracer_provider
  end

  # Any test that creates a transaction but doesn't complete it leaves an
  # OpenTelemetry context attached, which would pollute the next test's
  # `Trace.current_span` reading. spec_helper's `clear_current_transaction!`
  # clears the thread-local but not the OTel context — `complete_current!`
  # does both (it calls `complete` on the backend, which detaches).
  after { Appsignal::Transaction.complete_current! }

  include_examples "transaction lifecycle (mode-agnostic)"
  include_examples "transaction events (mode-agnostic)"

  # Helper: the root span (kind == :server / :consumer) vs the event spans
  # (kind == :internal by default for `tracer.start_span`).
  def root_span
    span_exporter.finished_spans.find { |s| [:server, :consumer].include?(s.kind) }
  end

  def event_spans
    span_exporter.finished_spans.reject { |s| [:server, :consumer].include?(s.kind) }
  end

  describe "OpenTelemetry root span shape" do
    it "starts an OTel root span with SpanKind::SERVER for HTTP_REQUEST" do
      Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      Appsignal::Transaction.complete_current!

      expect(span_exporter.finished_spans.size).to eq(1)
      span = span_exporter.finished_spans.first
      expect(span.kind).to eq(:server)
      expect(span.name).to eq("appsignal.transaction http_request")
    end

    it "uses SpanKind::CONSUMER for BACKGROUND_JOB" do
      Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)
      Appsignal::Transaction.complete_current!

      expect(span_exporter.finished_spans.first.kind).to eq(:consumer)
    end

    it "uses SpanKind::SERVER for ACTION_CABLE" do
      Appsignal::Transaction.create(Appsignal::Transaction::ACTION_CABLE)
      Appsignal::Transaction.complete_current!

      expect(span_exporter.finished_spans.first.kind).to eq(:server)
    end

    it "uses SpanKind::SERVER for an unknown custom namespace" do
      Appsignal::Transaction.create("my_custom_namespace")
      Appsignal::Transaction.complete_current!

      expect(span_exporter.finished_spans.first.kind).to eq(:server)
      expect(span_exporter.finished_spans.first.name)
        .to eq("appsignal.transaction my_custom_namespace")
    end
  end

  describe "OpenTelemetry current context" do
    it "makes the root span the OpenTelemetry current span between create and complete" do
      expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)

      Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)

      expect(::OpenTelemetry::Trace.current_span).not_to eq(::OpenTelemetry::Trace::Span::INVALID)
      expect(::OpenTelemetry::Trace.current_span.context.trace_id).not_to be_nil

      Appsignal::Transaction.complete_current!

      expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)
    end
  end

  describe "OpenTelemetry span emission timing" do
    it "emits no span until complete is called" do
      Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      expect(span_exporter.finished_spans).to be_empty

      Appsignal::Transaction.complete_current!
      expect(span_exporter.finished_spans.size).to eq(1)
    end
  end

  describe "events as OpenTelemetry child spans" do
    it "creates a child span on instrument with the event name as the span name" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("sql.active_record", "Query", "SELECT 1",
        Appsignal::EventFormatter::SQL_BODY_FORMAT) { nil }
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.first
      expect(span.name).to eq("sql.active_record")
      expect(span.parent_span_id).to eq(root_span.span_id)
    end

    it "writes db.query.text + db.system.name=other_sql for SQL_BODY_FORMAT events" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("sql.active_record", "Query", "SELECT 1",
        Appsignal::EventFormatter::SQL_BODY_FORMAT) { nil }
      Appsignal::Transaction.complete_current!

      attrs = event_spans.first.attributes
      expect(attrs["db.query.text"]).to eq("SELECT 1")
      expect(attrs["db.system.name"]).to eq("other_sql")
      expect(attrs["appsignal.title"]).to eq("Query")
      expect(attrs).not_to have_key("appsignal.body")
    end

    it "writes appsignal.body for default-format events (no db.* attrs)" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("custom.event", "Title", "Body",
        Appsignal::EventFormatter::DEFAULT) { nil }
      Appsignal::Transaction.complete_current!

      attrs = event_spans.first.attributes
      expect(attrs["appsignal.body"]).to eq("Body")
      expect(attrs["appsignal.title"]).to eq("Title")
      expect(attrs).not_to have_key("db.query.text")
      expect(attrs).not_to have_key("db.system.name")
    end

    it "omits appsignal.title when title is empty" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("custom.event", nil, "Body",
        Appsignal::EventFormatter::DEFAULT) { nil }
      Appsignal::Transaction.complete_current!

      expect(event_spans.first.attributes).not_to have_key("appsignal.title")
    end

    it "omits the body attribute when body is empty" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("custom.event", "Title", nil,
        Appsignal::EventFormatter::DEFAULT) { nil }
      Appsignal::Transaction.complete_current!

      attrs = event_spans.first.attributes
      expect(attrs).not_to have_key("appsignal.body")
      expect(attrs).not_to have_key("db.query.text")
    end

    it "makes the event span the OTel current span during the block" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      root_span_id = ::OpenTelemetry::Trace.current_span.context.span_id

      event_span_id_during_block = nil
      transaction.instrument("custom.event", "T", "B", Appsignal::EventFormatter::DEFAULT) do
        event_span_id_during_block = ::OpenTelemetry::Trace.current_span.context.span_id
      end

      expect(event_span_id_during_block).not_to eq(root_span_id)
      expect(::OpenTelemetry::Trace.current_span.context.span_id).to eq(root_span_id)

      Appsignal::Transaction.complete_current!
    end

    it "nests events: the inner span's parent is the outer event span" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      transaction.instrument("outer.event", "Outer", "outer body",
        Appsignal::EventFormatter::DEFAULT) do
        transaction.instrument("inner.event", "Inner", "inner body",
          Appsignal::EventFormatter::DEFAULT) { nil }
      end
      Appsignal::Transaction.complete_current!

      outer = event_spans.find { |s| s.name == "outer.event" }
      inner = event_spans.find { |s| s.name == "inner.event" }

      expect(inner.parent_span_id).to eq(outer.span_id)
      expect(outer.parent_span_id).to eq(root_span.span_id)
    end

    it "record_event creates a child span with backdated start_timestamp" do
      transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
      duration_ns = 1_000_000_000  # 1 second
      transaction.record_event("custom.event", "T", "B", duration_ns,
        Appsignal::EventFormatter::DEFAULT)
      Appsignal::Transaction.complete_current!

      span = event_spans.first
      expect(span.name).to eq("custom.event")
      expect(span.parent_span_id).to eq(root_span.span_id)
      # OTel timestamps are nanoseconds; allow a small slack for clock jitter.
      observed = span.end_timestamp - span.start_timestamp
      expect(observed).to be_within(50_000_000).of(duration_ns)
    end
  end
end
