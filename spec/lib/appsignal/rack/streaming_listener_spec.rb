require 'appsignal/rack/streaming_listener'

describe Appsignal::Rack::StreamingListener do
  let(:headers)  { {} }
  let(:env) do
    {
      'rack.input'     => StringIO.new,
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO'      => '/homepage',
      'QUERY_STRING'   => 'param=something'
    }
  end
  let(:app)      { double(:call => [200, headers, 'body']) }
  let(:listener) { Appsignal::Rack::StreamingListener.new(app, {}) }

  describe "#call" do
    context "when Appsignal is active" do
      before { Appsignal.stub(:active? => true) }

      it "should call `call_with_appsignal_monitoring`" do
        expect( listener ).to receive(:call_with_appsignal_monitoring)
      end
    end

    context "when Appsignal is not active" do
      before { Appsignal.stub(:active? => false) }

      it "should not call `call_with_appsignal_monitoring`" do
        expect( listener ).to_not receive(:call_with_appsignal_monitoring)
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
    let(:wrapper)     { Appsignal::StreamWrapper.new('body', transaction) }
    let(:raw_payload) { {:foo => :bar} }

    before do
      SecureRandom.stub(:uuid => '123')
      listener.stub(:raw_payload => raw_payload)
      Appsignal::Transaction.stub(:create => transaction)
    end

    it "should create a transaction" do
      expect( Appsignal::Transaction ).to receive(:create)
        .with('123', Appsignal::Transaction::HTTP_REQUEST, instance_of(Rack::Request))
        .and_return(transaction)

      listener.call_with_appsignal_monitoring(env)
    end

    it "should instrument the call" do
      expect( Appsignal ).to receive(:instrument)
        .with('process_action.rack')
        .and_yield

      listener.call_with_appsignal_monitoring(env)
    end

    it "should add `appsignal.action` to the transaction" do
      allow( Appsignal ).to receive(:instrument).and_yield

      env['appsignal.action'] = 'Action'

      expect( transaction ).to receive(:set_action).with('Action')

      listener.call_with_appsignal_monitoring(env)
    end

    it "should add the path, method and queue start to the transaction" do
      allow( Appsignal ).to receive(:instrument).and_yield

      expect( transaction ).to receive(:set_metadata).with('path', '/homepage')
      expect( transaction ).to receive(:set_metadata).with('method', 'GET')
      expect( transaction ).to receive(:set_http_or_background_queue_start)

      listener.call_with_appsignal_monitoring(env)
    end

    context "with an exception in the instrumentation call" do
      it "should add the exception to the transaction" do
        allow( app ).to receive(:call).and_raise(VerySpecificError.new)

        expect( transaction ).to receive(:set_error)

        listener.call_with_appsignal_monitoring(env) rescue VerySpecificError
      end
    end

    it "should wrap the body in a wrapper" do
      expect( Appsignal::StreamWrapper ).to receive(:new)
        .with('body', transaction)
        .and_return(wrapper)

      body = listener.call_with_appsignal_monitoring(env)[2]

      expect( body ).to be_a(Appsignal::StreamWrapper)
    end
  end
end

describe Appsignal::StreamWrapper do
  let(:stream)      { double }
  let(:transaction) { Appsignal::Transaction.create(SecureRandom.uuid, Appsignal::Transaction::HTTP_REQUEST, {}) }
  let(:wrapper)     { Appsignal::StreamWrapper.new(stream, transaction) }

  describe "#each" do
    it "should call the original stream" do
      expect( stream ).to receive(:each)

      wrapper.each
    end

    context "when each raises an error" do
      it "should add the exception to the transaction" do
        allow( stream ).to receive(:each)
          .and_raise(VerySpecificError.new)

        expect( transaction ).to receive(:set_error)

        wrapper.send(:each) rescue VerySpecificError
      end
    end
  end

  describe "#close" do
    it "should call the original stream and close the transaction" do
      expect( stream ).to receive(:close)
      expect( Appsignal::Transaction ).to receive(:complete_current!)

      wrapper.close
    end

    context "when each raises an error" do
      it "should add the exception to the transaction and close it" do
        allow( stream ).to receive(:close)
          .and_raise(VerySpecificError.new)

        expect( transaction ).to receive(:set_error)
        expect( Appsignal::Transaction ).to receive(:complete_current!)

        wrapper.send(:close) rescue VerySpecificError
      end
    end
  end
end
