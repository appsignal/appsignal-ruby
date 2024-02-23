describe Appsignal::Rack::GenericInstrumentation do
  before :context do
    start_agent
  end

  let(:app) { double(:call => true) }
  let(:env) { { :path => "/", :method => "GET" } }
  let(:options) { {} }
  let(:middleware) { Appsignal::Rack::GenericInstrumentation.new(app, options) }

  describe "#call" do
    before do
      allow(middleware).to receive(:raw_payload).and_return({})
    end

    context "when appsignal is active and there is no transaction in env" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "should call with monitoring" do
        expect(middleware).to receive(:call_with_new_appsignal_transaction).with(env)
      end
    end

    context "when appsignal is not active" do
      before { allow(Appsignal).to receive(:active?).and_return(false) }

      it "should not call with monitoring" do
        expect(middleware).to_not receive(:call_with_appsignal_monitoring)
      end

      it "should call the stack" do
        expect(app).to receive(:call).with(env)
      end
    end

    context "with multiple nested instances of the middleware" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "only creates and completes the transaction once" do
        expect(Appsignal::Transaction).to receive(:create).with(
          kind_of(String),
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(Rack::Request)
        ).once.and_return(double(:set_action_if_nil => nil, :set_http_or_background_queue_start => nil,
          :set_metadata => nil))
        expect(Appsignal::Transaction).to receive(:complete_current!).once

        inner = described_class.new(app, options)
        outer = described_class.new(inner, options)
        outermost = described_class.new(outer, options)

        _status, _headers, body = outermost.call(env)
        body.close
      end
    end

    after { middleware.call(env) }
  end

  describe "#call_with_appsignal_monitoring", :error => false do
    it "should create a transaction" do
      expect(Appsignal::Transaction).to receive(:create).with(
        kind_of(String),
        Appsignal::Transaction::HTTP_REQUEST,
        kind_of(Rack::Request)
      ).and_return(double(:set_action_if_nil => nil, :set_http_or_background_queue_start => nil,
        :set_metadata => nil))
    end

    it "should call the app" do
      expect(app).to receive(:call).with(env)
    end

    context "with an exception raised from call()", :error => true do
      let(:error) { ExampleException }
      let(:app) do
        double.tap do |d|
          allow(d).to receive(:call).and_raise(error)
        end
      end

      it "records the exception and completes the transaction" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
        expect(Appsignal::Transaction).to receive(:complete_current!)
      end
    end

    it "should set the action to unknown" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_action_if_nil).with("unknown")
    end

    context "with a route specified in the env" do
      before do
        env["appsignal.route"] = "GET /"
      end

      it "should set the action" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_action_if_nil).with("GET /")
      end
    end

    it "should set metadata" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata).twice
    end

    it "should set the queue start" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_http_or_background_queue_start)
    end

    after(:error => false) { middleware.call(env) }
    after(:error => true) { expect { middleware.call(env) }.to raise_error(error) }
  end
end
