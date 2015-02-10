require 'spec_helper'

describe Appsignal::Rack::JSExceptionCatcher do
  let(:app)     { double }
  let(:options) { double }

  describe "#initialize" do
    it "should log to the logger" do
      expect( Appsignal.logger ).to receive(:debug)
        .with('Initializing Appsignal::Rack::JSExceptionCatcher')

      Appsignal::Rack::JSExceptionCatcher.new(app, options)
    end
  end

  describe "#call" do
    let(:catcher) { Appsignal::Rack::JSExceptionCatcher.new(app, options) }

    context "when path is not `/appsignal_error_catcher`" do
      let(:env) { {'PATH_INFO' => '/foo'} }

      it "should call the next middleware" do
        expect( app ).to receive(:call).with(env)

        catcher.call(env)
      end
    end

    context "when path is `/appsignal_error_catcher`" do
      let(:transaction) { double(:complete! => true) }
      let(:env) do
        {
          'PATH_INFO'  => '/appsignal_error_catcher',
          'rack.input' => double(:read => '{"foo": "bar"}')
        }
      end

      it "should create a JSExceptionTransaction" do
        expect( Appsignal::JSExceptionTransaction ).to receive(:new)
          .with({'foo' => 'bar'})
          .and_return(transaction)

        expect( transaction ).to receive(:complete!)

        catcher.call(env)
      end
    end
  end

end
