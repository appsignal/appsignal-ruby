if grape_present?
  require 'appsignal/integrations/grape'

  describe Appsignal::Grape::Middleware do

    before :all do
      start_agent
    end

    let(:app)          { double(:call => true) }
    let(:api_endpoint) { double(:options => options) }
    let(:options)      { {
      :for    => 'Api::PostPut',
      :method => ['POST'],
      :path   => ['ping']
    }}
    let(:env) do
      http_request_env_with_data('api.endpoint' => api_endpoint)
    end
    let(:middleware) { Appsignal::Grape::Middleware.new(app) }

    describe "#call" do
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

        it "should call the app" do
          expect( app ).to receive(:call).with(env)
        end
      end

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      before { SecureRandom.stub(:uuid => '1') }

      it "should create a transaction" do
        Appsignal::Transaction.should_receive(:create).with(
          '1',
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(::Rack::Request)
        ).and_return(
          double(
            :set_action                         => nil,
            :set_http_or_background_queue_start => nil,
            :set_metadata                       => nil
          )
        )
      end

      it "should call the app" do
        app.should_receive(:call).with(env)
      end

      context "with an error" do
        let(:error) { VerySpecificError.new }
        let(:app) do
          double.tap do |d|
            d.stub(:call).and_raise(error)
          end
        end

        it "should set the error" do
          Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
        end
      end

      it "should set metadata" do
        Appsignal::Transaction.any_instance.should_receive(:set_metadata).twice
      end

      it "should set the action and queue start" do
        Appsignal::Transaction.any_instance.should_receive(:set_action).with('POST::Api::PostPut#ping')
        Appsignal::Transaction.any_instance.should_receive(:set_http_or_background_queue_start)
      end

      after { middleware.call(env) rescue VerySpecificError }
    end
  end
end
