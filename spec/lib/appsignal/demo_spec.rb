require "appsignal/demo"

describe Appsignal::Demo do
  before do
    # Ignore sleeps to speed up the test
    allow(described_class).to receive(:sleep)
  end

  describe ".transmit" do
    subject { described_class.transmit }

    context "without config" do
      it "returns false" do
        expect(silence { subject }).to eq(false)
      end
    end

    context "with config" do
      let(:config) { project_fixture_config("production") }
      before { Appsignal.config = config }

      it "returns true" do
        expect(subject).to eq(true)
      end

      it "creates demonstration samples" do
        expect(described_class).to receive(:create_example_error_request)
        expect(described_class).to receive(:create_example_performance_request)
        subject
      end
    end
  end

  describe ".create_example_error_request" do
    let!(:error_transaction) { http_request_transaction }
    let(:config) { project_fixture_config("production") }
    before do
      Appsignal.config = config
      expect(Appsignal::Transaction).to receive(:new).with(
        kind_of(String),
        Appsignal::Transaction::HTTP_REQUEST,
        kind_of(::Rack::Request),
        kind_of(Hash)
      ).and_return(error_transaction)
    end
    subject { described_class.send(:create_example_error_request) }

    it "sets an error" do
      expect(error_transaction).to receive(:set_error).with(kind_of(described_class::TestError))
      expect(error_transaction).to receive(:set_metadata).with("path", "/hello")
      expect(error_transaction).to receive(:set_metadata).with("method", "GET")
      expect(error_transaction).to receive(:set_metadata).with("demo_sample", "true")
      expect(error_transaction).to receive(:complete)
      subject
    end
  end

  describe ".create_example_performance_request" do
    let!(:performance_transaction) { http_request_transaction }
    let(:config) { project_fixture_config("production") }
    before do
      Appsignal.config = config
      expect(Appsignal::Transaction).to receive(:new).with(
        kind_of(String),
        Appsignal::Transaction::HTTP_REQUEST,
        kind_of(::Rack::Request),
        kind_of(Hash)
      ).and_return(performance_transaction)
    end
    subject { described_class.send(:create_example_performance_request) }

    it "sends a performance sample" do
      expect(performance_transaction).to receive(:start_event)
      expect(performance_transaction).to receive(:finish_event).with(
        "action_view.render",
        "Render hello.html.erb",
        "<h1>Hello world!</h1>",
        Appsignal::EventFormatter::DEFAULT
      )
      expect(performance_transaction).to receive(:set_metadata).with("path", "/hello")
      expect(performance_transaction).to receive(:set_metadata).with("method", "GET")
      expect(performance_transaction).to receive(:set_metadata).with("demo_sample", "true")
      expect(performance_transaction).to receive(:complete)
      subject
    end
  end
end
