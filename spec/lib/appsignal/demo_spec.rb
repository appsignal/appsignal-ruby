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
    before { start_agent }
    around { |example| keep_transactions { example.run } }

    it "sets an error" do
      described_class.send(:create_example_error_request)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
      expect(transaction).to have_action("DemoController#hello")
      expect(transaction).to have_error(
        "Appsignal::Demo::TestError",
        "Hello world! This is an error used for demonstration purposes."
      )
      expect(transaction).to include_metadata(
        "path" => "/hello",
        "method" => "GET",
        "demo_sample" => "true"
      )
      expect(transaction).to be_completed
    end
  end

  describe ".create_example_performance_request" do
    before { start_agent }
    around { |example| keep_transactions { example.run } }

    it "sends a performance sample" do
      described_class.send(:create_example_performance_request)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
      expect(transaction).to have_action("DemoController#hello")
      expect(transaction).to_not have_error
      expect(transaction).to include_metadata(
        "path" => "/hello",
        "method" => "GET",
        "demo_sample" => "true"
      )
      expect(transaction).to include_event(
        "name" => "action_view.render",
        "title" => "Render hello.html.erb",
        "body" => "<h1>Hello world!</h1>",
        "body_format" => Appsignal::EventFormatter::DEFAULT
      )
      expect(transaction).to be_completed
    end
  end
end
