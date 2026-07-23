# frozen_string_literal: true

describe Appsignal::Transaction::ExtensionBackend do
  before { start_agent }

  let(:backend) { described_class.new("abc-123", Appsignal::Transaction::HTTP_REQUEST) }

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
          :handle => existing_handle
        )

        expect(backend_with_handle.instance_variable_get(:@handle)).to be(existing_handle)
      end
    end

    context "when the extension cannot be loaded", :extension_installation_failure do
      around { |example| Appsignal::Testing.without_testing { example.run } }

      it "falls back to a MockTransaction" do
        backend = described_class.new("abc-123", Appsignal::Transaction::HTTP_REQUEST)
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

  describe "#params_mapping" do
    it "maps every params channel to the single agent params bucket" do
      expect(backend.params_mapping).to eq(
        :params => :params,
        :request_payload => :params,
        :function_parameters => :params
      )
    end
  end

  describe "method delegation" do
    let(:handle) { backend.instance_variable_get(:@handle) }

    it "forwards #start_event to the handle" do
      expect(handle).to receive(:start_event).with(0)
      backend.start_event
    end

    it "forwards #finish_event to the handle" do
      expect(handle).to receive(:finish_event).with("name", "title", "body", 1, 0)
      backend.finish_event("name", "title", "body", 1)
    end

    it "forwards #record_event to the handle" do
      expect(handle).to receive(:record_event).with("name", "title", "body", 1, 1000, 0)
      backend.record_event("name", "title", "body", 1, 1000)
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
      allow(backend).to receive(:set_sample_data)
      data = Appsignal::Utils::Data.generate(["line 1"])
      expect(Appsignal::Utils::Data).to receive(:generate).with(["line 1"]).and_return(data)
      expect(handle).to receive(:set_error).with("RuntimeError", "boom", data)
      backend.set_error("RuntimeError", "boom", ["line 1"], [], false)
    end

    it "forwards an empty Data array when the backtrace is nil" do
      allow(backend).to receive(:set_sample_data)
      data = Appsignal::Extension.data_array_new
      expect(Appsignal::Extension).to receive(:data_array_new).and_return(data)
      expect(handle).to receive(:set_error).with("RuntimeError", "boom", data)
      backend.set_error("RuntimeError", "boom", nil, [], false)
    end

    it "flushes the causes as error_causes sample data" do
      allow(handle).to receive(:set_error)
      causes = [{
        :name => "ArgumentError",
        :message => "bad arg",
        :backtrace => ["/app/lib/foo.rb:10:in `bar'"]
      }]
      expect(backend).to receive(:set_sample_data).with("error_causes", an_instance_of(Array))
      backend.set_error("RuntimeError", "boom", ["line 1"], causes, false)
    end

    it "forwards #finish to the handle and returns its value" do
      expect(handle).to receive(:finish).with(0).and_return(true)
      expect(backend.finish).to eq(true)
    end

    it "forwards #complete to the handle" do
      expect(handle).to receive(:complete)
      backend.complete
    end

    it "drops the transaction on #discard without completing the handle" do
      expect(handle).to_not receive(:complete)
      backend.discard
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

  describe "breadcrumbs" do
    let(:handle) { backend.instance_variable_get(:@handle) }

    it "caps the buffer at the breadcrumb limit, keeping the most recent" do
      25.times { |i| backend.add_breadcrumb(:index => i) }

      buffer = backend.instance_variable_get(:@breadcrumbs)
      expect(buffer.length).to eq(Appsignal::Transaction::BREADCRUMB_LIMIT)
      expect(buffer.first).to eq(:index => 5)
      expect(buffer.last).to eq(:index => 24)
    end

    it "flushes the buffered breadcrumbs as sample data on complete" do
      backend.add_breadcrumb(:action => "click")
      data = Appsignal::Utils::Data.generate([{ :action => "click" }])
      expect(Appsignal::Utils::Data).to receive(:generate)
        .with([{ :action => "click" }]).and_return(data)
      expect(handle).to receive(:set_sample_data).with("breadcrumbs", data)
      expect(handle).to receive(:complete)

      backend.complete
    end

    it "does not flush sample data when there are no breadcrumbs" do
      expect(handle).to_not receive(:set_sample_data)
      expect(handle).to receive(:complete)

      backend.complete
    end

    it "copies the buffer into a duplicate" do
      backend.add_breadcrumb(:action => "click")
      duplicate = backend.duplicate("new-id")

      expect(duplicate.instance_variable_get(:@breadcrumbs)).to eq([{ :action => "click" }])
    end
  end

  describe "error_causes projection" do
    it "projects causes to the first-line shape" do
      causes = [{
        :name => "ArgumentError",
        :message => "bad arg",
        :backtrace => ["/app/lib/foo.rb:10:in `bar'"]
      }]
      projected = backend.send(:error_causes_sample_data, causes, false)

      expect(projected.first).to include(:name => "ArgumentError", :message => "bad arg")
      expect(projected.first[:first_line]["original"]).to eq("/app/lib/foo.rb:10:in `bar'")
      expect(projected.first[:first_line]["line"]).to eq(10)
    end

    it "marks the last cause as not the root cause when the chain was truncated" do
      causes = [{ :name => "E", :message => "m", :backtrace => ["/app/x.rb:1:in `y'"] }]

      expect(backend.send(:error_causes_sample_data, causes, true).last[:is_root_cause])
        .to eq(false)
    end

    it "leaves the first line nil for a cause with no backtrace" do
      causes = [{ :name => "E", :message => "m", :backtrace => nil }]

      expect(backend.send(:error_causes_sample_data, causes, false).first[:first_line]).to be_nil
    end
  end

  describe "#supports_multiple_errors?" do
    it "returns false (extra errors are reported as duplicate transactions)" do
      expect(backend.supports_multiple_errors?).to eq(false)
    end
  end
end
