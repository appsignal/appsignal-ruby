# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  require "appsignal/rack/hanami_instrumentation"

  describe Appsignal::Rack::HanamiInstrumentation do
    before :context do
      start_agent
    end

    let(:app) { double(:call => true) }
    let(:env) do
      Rack::MockRequest.env_for(
        "/books",
        "router.params" => router_params,
        :method => "POST"
      )
    end

    let(:router_params) { { :foo => "bar", :baz => "qux" } }
    let(:middleware) { described_class.new(app) }

    describe "#call" do
      before do
        allow(middleware).to receive(:raw_payload).and_return({})
      end

      context "when appsignal is active" do
        before { allow(Appsignal).to receive(:active?).and_return(true) }

        it "should call with monitoring" do
          expect(middleware).to receive(:call_with_appsignal_monitoring).with(env)
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

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring", :error => false do
      it "should create a transaction" do
        transaction = double(:set_action_if_nil => nil, :set_http_or_background_queue_start => nil, :set_metadata => nil)

        expect(Appsignal::Transaction).to receive(:create).with(
          kind_of(String),
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(Hanami::Action::Request)
        ).and_return(transaction)
        expect(transaction).to receive(:params=).with(router_params)
      end

      it "should call the app" do
        expect(app).to receive(:call).with(env)
      end

      context "with an exception", :error => true do
        let(:error) { ExampleException }
        let(:app) do
          double.tap do |d|
            allow(d).to receive(:call).and_raise(error)
          end
        end

        it "records the exception" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
        end
      end

      it "sets params" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:params=).with(router_params)
      end

      it "sets the action name" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_action_if_nil).with("POST /books")
      end

      it "sets the metadata" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata).twice
      end

      it "sets the queue start" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_http_or_background_queue_start)
      end

      after(:error => false) { middleware.call(env) }
      after(:error => true) { expect { middleware.call(env) }.to raise_error(error) }
    end
  end
end
