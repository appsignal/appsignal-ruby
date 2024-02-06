require "appsignal/rack/streaming_listener"

describe Appsignal::Rack::StreamingListener do
  before(:context) { start_agent }
  let(:headers) { {} }
  let(:env) do
    {
      "rack.input" => StringIO.new,
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/homepage",
      "QUERY_STRING" => "param=something"
    }
  end
  let(:app)      { double(:call => [200, headers, "body"]) }
  let(:listener) { Appsignal::Rack::StreamingListener.new(app, {}) }

  describe "#call" do
    context "when Appsignal is active" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "should call `call_with_appsignal_monitoring`" do
        expect(listener).to receive(:call_with_appsignal_monitoring)
      end
    end

    context "when Appsignal is not active" do
      before { allow(Appsignal).to receive(:active?).and_return(false) }

      it "should not call `call_with_appsignal_monitoring`" do
        expect(listener).to_not receive(:call_with_appsignal_monitoring)
      end
    end

    after { listener.call(env) }
  end

  describe "#call_with_appsignal_monitoring" do
    let!(:transaction) do
      Appsignal::Transaction.create(
        SecureRandom.uuid,
        Appsignal::Transaction::HTTP_REQUEST,
        ::Rack::Request.new(env)
      )
    end
    let(:wrapper)     { Appsignal::StreamWrapper.new("body", transaction) }
    let(:raw_payload) { { :foo => :bar } }

    before do
      allow(SecureRandom).to receive(:uuid).and_return("123")
      allow(listener).to receive(:raw_payload).and_return(raw_payload)
      allow(Appsignal::Transaction).to receive(:create).and_return(transaction)
    end

    it "should create a transaction" do
      expect(Appsignal::Transaction).to receive(:create)
        .with("123", Appsignal::Transaction::HTTP_REQUEST, instance_of(Rack::Request))
        .and_return(transaction)

      listener.call_with_appsignal_monitoring(env)
    end

    it "should instrument the call" do
      expect(Appsignal).to receive(:instrument)
        .with("process_action.rack")
        .and_yield

      listener.call_with_appsignal_monitoring(env)
    end

    it "should add `appsignal.action` to the transaction" do
      allow(Appsignal).to receive(:instrument).and_yield

      env["appsignal.action"] = "Action"

      expect(transaction).to receive(:set_action_if_nil).with("Action")

      listener.call_with_appsignal_monitoring(env)
    end

    it "should add the path, method and queue start to the transaction" do
      allow(Appsignal).to receive(:instrument).and_yield

      expect(transaction).to receive(:set_metadata).with("path", "/homepage")
      expect(transaction).to receive(:set_metadata).with("method", "GET")
      expect(transaction).to receive(:set_http_or_background_queue_start)

      listener.call_with_appsignal_monitoring(env)
    end

    context "with an exception in the instrumentation call" do
      let(:error) { ExampleException }

      it "should add the exception to the transaction" do
        allow(app).to receive(:call).and_raise(error)

        expect(transaction).to receive(:set_error).with(error)

        expect do
          listener.call_with_appsignal_monitoring(env)
        end.to raise_error(error)
      end
    end

    it "should wrap the response body in a wrapper" do
      body = listener.call_with_appsignal_monitoring(env)[2]

      expect(body).to be_kind_of(Appsignal::Rack::BodyWrapper)
    end
  end
end

describe Appsignal::StreamWrapper do
  it ".new returns an EnumerableWrapper" do
    fake_body = double(:each => nil)
    fake_txn = double
    stream_wrapper = Appsignal::StreamWrapper.new(fake_body, fake_txn)
    expect(stream_wrapper).to be_kind_of(Appsignal::Rack::EnumerableBodyWrapper)
  end
end
