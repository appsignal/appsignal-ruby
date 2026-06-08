# frozen_string_literal: true

describe Appsignal::Transaction::ExtensionBackend do
  before { start_agent }

  let(:backend) { described_class.new("abc-123", Appsignal::Transaction::HTTP_REQUEST, 0) }

  describe "#initialize" do
    it "wraps a real extension transaction when the extension is loaded" do
      handle = backend.instance_variable_get(:@handle)
      expect(handle).to be_kind_of(Appsignal::Extension::Transaction)
    end

    context "when an existing handle is passed in" do
      it "wraps that handle directly without starting a new transaction" do
        existing_handle = Appsignal::Extension.start_transaction("other-id", "background_job", 0)

        backend_with_handle = described_class.new(
          "ignored-id",
          "ignored-namespace",
          0,
          :handle => existing_handle
        )

        expect(backend_with_handle.instance_variable_get(:@handle)).to be(existing_handle)
      end
    end

    context "when the extension cannot be loaded", :extension_installation_failure do
      around { |example| Appsignal::Testing.without_testing { example.run } }

      it "falls back to a MockTransaction" do
        backend = described_class.new("abc-123", Appsignal::Transaction::HTTP_REQUEST, 0)
        expect(backend.instance_variable_get(:@handle))
          .to be_kind_of(Appsignal::Extension::MockTransaction)
      end
    end
  end

  describe "#duplicate" do
    it "returns a new ExtensionBackend wrapping a duplicated extension transaction" do
      duplicate = backend.duplicate("new-id")

      expect(duplicate).to be_kind_of(described_class)
      expect(duplicate).not_to be(backend)
      expect(duplicate.instance_variable_get(:@handle))
        .not_to be(backend.instance_variable_get(:@handle))
    end
  end

  describe "method delegation" do
    let(:handle) { backend.instance_variable_get(:@handle) }

    it "forwards #start_event to the handle" do
      expect(handle).to receive(:start_event).with(0)
      backend.start_event(0)
    end

    it "forwards #finish_event to the handle" do
      expect(handle).to receive(:finish_event).with("name", "title", "body", 1, 0)
      backend.finish_event("name", "title", "body", 1, 0)
    end

    it "forwards #record_event to the handle" do
      expect(handle).to receive(:record_event).with("name", "title", "body", 1, 1000, 0)
      backend.record_event("name", "title", "body", 1, 1000, 0)
    end

    it "forwards #set_action to the handle" do
      expect(handle).to receive(:set_action).with("MyAction")
      backend.set_action("MyAction")
    end

    it "forwards #set_namespace to the handle" do
      expect(handle).to receive(:set_namespace).with("background_job")
      backend.set_namespace("background_job")
    end

    it "forwards #set_queue_start to the handle" do
      expect(handle).to receive(:set_queue_start).with(123_456)
      backend.set_queue_start(123_456)
    end

    it "forwards #set_metadata to the handle" do
      expect(handle).to receive(:set_metadata).with("key", "value")
      backend.set_metadata("key", "value")
    end

    it "serializes the sample data to Data and forwards #set_sample_data to the handle" do
      raw = { "a" => 1 }
      data = Appsignal::Utils::Data.generate(raw)
      expect(Appsignal::Utils::Data).to receive(:generate).with(raw).and_return(data)
      expect(handle).to receive(:set_sample_data).with("params", data)
      backend.set_sample_data("params", raw)
    end

    it "serializes the backtrace Array to Data and forwards #set_error to the handle" do
      data = Appsignal::Utils::Data.generate(["line 1"])
      expect(Appsignal::Utils::Data).to receive(:generate).with(["line 1"]).and_return(data)
      expect(handle).to receive(:set_error).with("RuntimeError", "boom", data)
      backend.set_error("RuntimeError", "boom", ["line 1"], [])
    end

    it "forwards an empty Data array when the backtrace is nil" do
      data = Appsignal::Extension.data_array_new
      expect(Appsignal::Extension).to receive(:data_array_new).and_return(data)
      expect(handle).to receive(:set_error).with("RuntimeError", "boom", data)
      backend.set_error("RuntimeError", "boom", nil, [])
    end

    it "forwards #finish to the handle and returns its value" do
      expect(handle).to receive(:finish).with(0).and_return(true)
      expect(backend.finish(0)).to eq(true)
    end

    it "forwards #complete to the handle" do
      expect(handle).to receive(:complete)
      backend.complete
    end

    it "forwards #to_json to the handle" do
      expect(handle).to receive(:to_json).and_return("{}")
      expect(backend.to_json).to eq("{}")
    end

    it "forwards #queue_start to the handle" do
      backend.set_queue_start(99)
      expect(backend.queue_start).to eq(99)
    end

    it "forwards #_completed? to the handle" do
      expect(backend._completed?).to eq(false)
      backend.complete
      expect(backend._completed?).to eq(true)
    end
  end

  describe "#supports_multiple_errors?" do
    it "returns false (extra errors are reported as duplicate transactions)" do
      expect(backend.supports_multiple_errors?).to eq(false)
    end
  end
end
