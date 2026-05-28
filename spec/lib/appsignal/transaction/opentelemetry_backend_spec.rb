# frozen_string_literal: true

describe Appsignal::Transaction::OpenTelemetryBackend do
  let(:backend) { described_class.new("abc-123", Appsignal::Transaction::HTTP_REQUEST, 0) }

  it "constructs without an extension or an OpenTelemetry SDK booted" do
    expect { backend }.not_to raise_error
  end

  describe "write methods (no-op for step 1)" do
    it "accepts #start_event without raising" do
      expect { backend.start_event(0) }.not_to raise_error
    end

    it "accepts #finish_event without raising" do
      expect { backend.finish_event("name", "title", "body", 1, 0) }.not_to raise_error
    end

    it "accepts #record_event without raising" do
      expect { backend.record_event("name", "title", "body", 1, 1000, 0) }.not_to raise_error
    end

    it "accepts #set_action without raising" do
      expect { backend.set_action("MyAction") }.not_to raise_error
    end

    it "accepts #set_namespace without raising" do
      expect { backend.set_namespace("background_job") }.not_to raise_error
    end

    it "accepts #set_queue_start without raising" do
      expect { backend.set_queue_start(123_456) }.not_to raise_error
    end

    it "accepts #set_metadata without raising" do
      expect { backend.set_metadata("key", "value") }.not_to raise_error
    end

    it "accepts #set_sample_data without raising" do
      expect { backend.set_sample_data("params", "anything") }.not_to raise_error
    end

    it "accepts #set_error without raising" do
      expect { backend.set_error("RuntimeError", "boom", "backtrace") }.not_to raise_error
    end
  end

  describe "#finish" do
    it "returns false so Transaction#complete does not run the sample_data path" do
      expect(backend.finish(0)).to eq(false)
    end
  end

  describe "#complete" do
    it "marks the backend completed without raising" do
      expect(backend._completed?).to eq(false)
      backend.complete
      expect(backend._completed?).to eq(true)
    end
  end

  describe "#duplicate" do
    it "returns a new OpenTelemetryBackend instance with the new id" do
      duplicate = backend.duplicate("new-id")

      expect(duplicate).to be_kind_of(described_class)
      expect(duplicate).not_to be(backend)
      expect(duplicate.instance_variable_get(:@transaction_id)).to eq("new-id")
    end
  end

  describe "#to_json" do
    it 'returns "{}" so Transaction#to_h yields an empty Hash' do
      expect(backend.to_json).to eq("{}")
      expect(JSON.parse(backend.to_json)).to eq({})
    end
  end

  describe "#queue_start" do
    it "returns nil (set_queue_start is a no-op for now)" do
      backend.set_queue_start(123_456)
      expect(backend.queue_start).to be_nil
    end
  end

  # Smoke test: a Transaction backed by an OpenTelemetryBackend (the collector-mode
  # configuration) exercises every public API path without raising, and emits no
  # OpenTelemetry spans yet. Span emission lands in subsequent steps. The backend
  # is injected via the `backend:` kwarg here — the `Appsignal::Backends.transaction`
  # dispatcher is covered in `spec/lib/appsignal/backends_spec.rb`.
  describe "Transaction backed by this backend (collector-mode shape)" do
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
      start_agent
      ::OpenTelemetry.tracer_provider = tracer_provider
    end

    def new_transaction_with_otel_backend(namespace = Appsignal::Transaction::HTTP_REQUEST)
      Appsignal::Transaction.new(
        namespace,
        :backend => described_class.new("abc-123", namespace, 0)
      )
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

    it "emits no OpenTelemetry spans (step-1 backend is a no-op)" do
      transaction = new_transaction_with_otel_backend
      transaction.start_event
      transaction.finish_event("event", "title", "body", 1)
      transaction.complete

      expect(span_exporter.finished_spans).to be_empty
    end
  end
end
