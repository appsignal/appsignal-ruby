require 'spec_helper'

begin
  require 'sinatra'
  require 'appsignal/integrations/sinatra'
rescue LoadError
end

if defined?(::Sinatra)
  describe Appsignal::Rack::SinatraInstrumentation do
    before :all do
      start_agent
    end

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) { {'sinatra.route' => 'GET /', :path => '/', :method => 'GET'} }
    let(:options) { {} }
    let(:middleware) { Appsignal::Rack::SinatraInstrumentation.new(app, options) }

    describe "#call" do
      before do
        middleware.stub(:raw_payload => {})
      end

      context "when appsignal is active" do
        before { Appsignal.stub(:active? => true) }

        it "should call with monitoring" do
          expect( middleware ).to receive(:call_with_appsignal_monitoring).with(env)
        end
      end

      context "when appsignal is not active" do
        before { Appsignal.stub(:active? => false) }

        it "should not call with monitoring" do
          expect( middleware ).to_not receive(:call_with_appsignal_monitoring)
        end

        it "should call the stack" do
          expect( app ).to receive(:call).with(env)
        end
      end

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      it "should create a transaction" do
        Appsignal::Transaction.should_receive(:create).with(
          kind_of(String),
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(Sinatra::Request)
        ).and_return(double(:set_action => nil, :set_http_or_background_queue_start => nil, :set_metadata => nil))
      end

      it "should call the app" do
        app.should_receive(:call).with(env)
      end

      context "with an error" do
        let(:error) { VerySpecificError.new }
        let(:app) do
          double.tap do |d|
            d.stub(:call).and_raise(error)
            d.stub(:settings => settings)
          end
        end

        it "should set the error" do
          Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
        end
      end

      context "with an error in sinatra.error" do
        let(:error) { VerySpecificError.new }
        let(:env) { {'sinatra.error' => error} }

        it "should set the error" do
          Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
        end

        context "if raise_errors is on" do
          let(:settings) { double(:raise_errors => true) }

          it "should not set the error" do
            Appsignal::Transaction.any_instance.should_not_receive(:set_error)
          end
        end

        context "if sinatra.skip_appsignal_error is set" do
          let(:env) { {'sinatra.error' => error, 'sinatra.skip_appsignal_error' => true} }

          it "should not set the error" do
            Appsignal::Transaction.any_instance.should_not_receive(:set_error)
          end
        end
      end

      it "should set the action" do
        Appsignal::Transaction.any_instance.should_receive(:set_action).with('GET /')
      end

      it "should set metadata" do
        Appsignal::Transaction.any_instance.should_receive(:set_metadata).twice
      end

      it "should set the queue start" do
        Appsignal::Transaction.any_instance.should_receive(:set_http_or_background_queue_start)
      end

      context "with overridden request class and params method" do
        let(:options) { {:request_class => ::Rack::Request, :params_method => :filtered_params} }

        it "should use the overridden request class and params method" do
          request = ::Rack::Request.new(env)
          ::Rack::Request.should_receive(:new).
                          with(env.merge(:params_method => :filtered_params)).
                          at_least(:once).
                          and_return(request)
        end
      end

      after { middleware.call(env) rescue VerySpecificError }
    end
  end
end
