require 'spec_helper'
require 'appsignal/rack/streaming_listener'

describe Appsignal::Rack::StreamingListener do
  let(:headers)  { {} }
  let(:env)      { {} }
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
    let!(:transaction) { Appsignal::Transaction.create(SecureRandom.uuid, env) }
    let(:wrapper)      { Appsignal::StreamWrapper.new('body', transaction) }
    let(:raw_payload)  { {:foo => :bar} }

    before do
      SecureRandom.stub(:uuid => '123')
      listener.stub(:raw_payload => raw_payload)
      Appsignal::Transaction.stub(:create => transaction)
    end

    it "should create a transaction" do
      expect( Appsignal::Transaction ).to receive(:create)
        .with('123', env)
        .and_return(transaction)

      listener.call_with_appsignal_monitoring(env)
    end

    it "should instrument the call" do
      expect( ActiveSupport::Notifications ).to receive(:instrument)
        .with('process_action.rack', raw_payload)
        .and_yield(raw_payload)

      listener.call_with_appsignal_monitoring(env)
    end

    it "should add `appsignal.action` to the payload" do
      allow( ActiveSupport::Notifications ).to receive(:instrument)
        .and_yield(raw_payload)

      env['appsignal.action'] = 'Action'
      listener.call_with_appsignal_monitoring(env)

      expect( raw_payload ).to eql({:foo => :bar, :action => 'Action'})
    end

    context "with an exception in the instrumentation call" do
      it "should add the exception to the transaction" do
        allow( app ).to receive(:call).and_raise(VerySpecificError.new('broken'))

        expect( transaction ).to receive(:add_exception)

        listener.call_with_appsignal_monitoring(env) rescue VerySpecificError
      end
    end

    it "should wrap the body in a wrapper" do
      expect( Appsignal::StreamWrapper ).to receive(:new)
        .with('body', transaction)
        .and_return(wrapper)

      status, headers, body = listener.call_with_appsignal_monitoring(env)

      expect( body ).to be_a(Appsignal::StreamWrapper)
    end
  end

  describe "#raw_payload" do
    let(:env) do
      {
        'rack.input'     => StringIO.new,
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO'      => '/homepage',
        'QUERY_STRING'   => 'param=something'
      }
    end

    it "should return an Appsignal compatible playload" do
      expect( listener.raw_payload(env) ).to eql({
        :params   => {'param' => 'something'},
        :session  => {},
        :method   => 'GET',
        :path     => '/homepage'
      })
    end
  end
end

describe Appsignal::StreamWrapper do
  let(:stream)       { double }
  let(:transaction)  { Appsignal::Transaction.create(SecureRandom.uuid, {}) }
  let(:wrapper)      { Appsignal::StreamWrapper.new(stream, transaction) }

  describe "#each" do
    it "should call the original stream" do
      expect( stream ).to receive(:each)

      wrapper.each
    end

    context "when each raises an error" do
      it "should add the exception to the transaction" do
        allow( stream ).to receive(:each)
          .and_raise(VerySpecificError.new('broken'))

        expect( transaction ).to receive(:add_exception)

        wrapper.send(:each) rescue VerySpecificError
      end
    end
  end

  describe "#close" do
    it "should call the original stream and close the transaction" do
      expect( stream ).to receive(:close)
      expect( transaction ).to receive(:complete!)

      wrapper.close
    end

    context "when each raises an error" do
      it "should add the exception to the transaction and close it" do
        allow( stream ).to receive(:close)
          .and_raise(VerySpecificError.new('broken'))

        expect( transaction ).to receive(:add_exception)
        expect( transaction ).to receive(:complete!)

        wrapper.send(:close) rescue VerySpecificError
      end
    end
  end
end
