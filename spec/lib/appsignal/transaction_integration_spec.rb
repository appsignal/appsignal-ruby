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

  it "serializes id, namespace and completed? via to_h after completion" do
    transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
    keep_transactions { Appsignal::Transaction.complete_current! }

    expect(transaction).to have_id(transaction.transaction_id)
    expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
    expect(transaction).to be_completed
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
end
