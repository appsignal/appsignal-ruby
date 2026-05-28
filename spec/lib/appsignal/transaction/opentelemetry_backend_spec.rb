# frozen_string_literal: true

require "opentelemetry/sdk"

describe Appsignal::Transaction::OpenTelemetryBackend do
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
  end

  # Each `create_backend` call constructs a real backend, which attaches an
  # OTel context on initialize. We track them all here and complete any that
  # the test didn't complete itself, so leftover spans / context attachments
  # don't pollute the next test.
  after do
    @backends_created.each { |backend| backend.complete unless backend._completed? }
  end

  def create_backend(namespace = "http_request")
    described_class.new("abc-123", namespace, 0).tap { |b| @backends_created << b }
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
      "http_request"   => :server,
      "background_job" => :consumer,
      "action_cable"   => :server,
      "some_custom_ns" => :server
    }.each do |namespace, expected_kind|
      it "maps namespace #{namespace.inspect} to SpanKind #{expected_kind.inspect}" do
        create_backend(namespace).complete
        expect(span_exporter.finished_spans.first.kind).to eq(expected_kind)
      end
    end

    it "attaches the new span as the OpenTelemetry current span" do
      backend = create_backend
      expect(::OpenTelemetry::Trace.current_span)
        .to eq(backend.instance_variable_get(:@span))
    end

    it "nests under the current OpenTelemetry context (free distributed-tracing inheritance)" do
      outer_tracer = ::OpenTelemetry.tracer_provider.tracer("outer")
      outer = outer_tracer.start_span("outer")
      outer_token =
        ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(outer))
      begin
        backend = create_backend
        backend_span = backend.instance_variable_get(:@span)
        expect(backend_span.parent_span_id).to eq(outer.context.span_id)
      ensure
        ::OpenTelemetry::Context.detach(outer_token)
        outer.finish
      end
    end
  end

  describe "write methods (no-op for step 2 — implementations land in subsequent steps)" do
    it "accepts #start_event without raising" do
      expect { create_backend.start_event(0) }.not_to raise_error
    end

    it "accepts #finish_event without raising" do
      expect { create_backend.finish_event("name", "title", "body", 1, 0) }.not_to raise_error
    end

    it "accepts #record_event without raising" do
      expect { create_backend.record_event("name", "title", "body", 1, 1000, 0) }.not_to raise_error
    end

    it "accepts #set_action without raising" do
      expect { create_backend.set_action("MyAction") }.not_to raise_error
    end

    it "accepts #set_namespace without raising" do
      expect { create_backend.set_namespace("background_job") }.not_to raise_error
    end

    it "accepts #set_queue_start without raising" do
      expect { create_backend.set_queue_start(123_456) }.not_to raise_error
    end

    it "accepts #set_metadata without raising" do
      expect { create_backend.set_metadata("key", "value") }.not_to raise_error
    end

    it "accepts #set_sample_data without raising" do
      expect { create_backend.set_sample_data("params", "anything") }.not_to raise_error
    end

    it "accepts #set_error without raising" do
      expect { create_backend.set_error("RuntimeError", "boom", "backtrace") }.not_to raise_error
    end
  end

  describe "#finish" do
    it "returns false so Transaction#complete does not run the sample_data path" do
      expect(create_backend.finish(0)).to eq(false)
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
  end

  describe "#duplicate" do
    # Multi-error duplicate is dead code in collector mode until errors are
    # wired up in a later step (one span + multiple `record_exception` events
    # will replace the duplicate-per-error model). For now we just preserve
    # the shape so `Transaction#complete`'s duplicate loop won't crash.
    it "returns a new OpenTelemetryBackend instance with the new id" do
      backend = create_backend
      duplicate = backend.duplicate("new-id")
      @backends_created << duplicate

      expect(duplicate).to be_kind_of(described_class)
      expect(duplicate).not_to be(backend)
      expect(duplicate.instance_variable_get(:@transaction_id)).to eq("new-id")
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
      backend = described_class.new("abc-123", namespace, 0)
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

    it "emits exactly one OTel root span on completion" do
      transaction = new_transaction_with_otel_backend
      transaction.start_event
      transaction.finish_event("event", "title", "body", 1)
      transaction.complete

      expect(span_exporter.finished_spans.size).to eq(1)
      expect(span_exporter.finished_spans.first.kind).to eq(:server)
    end
  end
end
