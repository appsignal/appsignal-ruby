if DependencyHelper.sinatra_present?
  require "appsignal/integrations/sinatra"

  describe Appsignal::Rack::SinatraInstrumentation do
    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) { { "sinatra.route" => "GET /", :path => "/", :method => "GET" } }
    let(:middleware) { Appsignal::Rack::SinatraInstrumentation.new(app) }

    describe "#call" do
      before do
        start_agent
        allow(middleware).to receive(:raw_payload).and_return({})
        allow(Appsignal).to receive(:active?).and_return(true)
      end

      it "should call without monitoring" do
        expect(Appsignal::Transaction).to_not receive(:create)
      end

      after { middleware.call(env) }
    end

    describe ".settings" do
      subject { middleware.settings }

      it "should return the app's settings" do
        expect(subject).to eq(app.settings)
      end
    end
  end

  describe Appsignal::Rack::SinatraBaseInstrumentation do
    before :context do
      start_agent
    end

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) { { "sinatra.route" => "GET /", :path => "/", :method => "GET" } }
    let(:options) { {} }
    let(:middleware) { Appsignal::Rack::SinatraBaseInstrumentation.new(app, options) }

    describe "#initialize" do
      context "with no settings method in the Sinatra app" do
        let(:app) { double(:call => true) }

        it "should not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with no raise_errors setting in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double) }

        it "should not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned off in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => false)) }

        it "should raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned on in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => true)) }

        it "should raise errors" do
          expect(middleware.raise_errors_on).to be(true)
        end
      end
    end

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
        expect(Appsignal::Transaction).to receive(:create).with(
          kind_of(String),
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(Sinatra::Request),
          kind_of(Hash)
        ).and_return(double(:set_action_if_nil => nil, :set_http_or_background_queue_start => nil,
          :set_metadata => nil))
      end

      it "should call the app" do
        expect(app).to receive(:call).with(env)
      end

      context "with an error", :error => true do
        let(:error) { ExampleException }
        let(:app) do
          double.tap do |d|
            allow(d).to receive(:call).and_raise(error)
            allow(d).to receive(:settings).and_return(settings)
          end
        end

        it "records the exception" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
        end
      end

      context "with an error in sinatra.error" do
        let(:error) { ExampleException }
        let(:env) { { "sinatra.error" => error } }

        it "records the exception" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
        end

        context "when raise_errors is on" do
          let(:settings) { double(:raise_errors => true) }

          it "does not record the error" do
            expect_any_instance_of(Appsignal::Transaction).to_not receive(:set_error)
          end
        end

        context "if sinatra.skip_appsignal_error is set" do
          let(:env) { { "sinatra.error" => error, "sinatra.skip_appsignal_error" => true } }

          it "does not record the error" do
            expect_any_instance_of(Appsignal::Transaction).to_not receive(:set_error)
          end
        end
      end

      describe "action name" do
        it "should set the action" do
          expect_any_instance_of(Appsignal::Transaction)
            .to receive(:set_action_if_nil).with("GET /")
        end

        context "without 'sinatra.route' env" do
          let(:env) { { :path => "/", :method => "GET" } }

          it "returns nil" do
            expect_any_instance_of(Appsignal::Transaction).to receive(:set_action_if_nil).with(nil)
          end
        end

        context "with mounted modular application" do
          before { env["SCRIPT_NAME"] = "/api" }

          it "should call set_action with an application prefix path" do
            expect_any_instance_of(Appsignal::Transaction)
              .to receive(:set_action_if_nil).with("GET /api/")
          end

          context "without 'sinatra.route' env" do
            let(:env) { { :path => "/", :method => "GET" } }

            it "returns nil" do
              expect_any_instance_of(Appsignal::Transaction)
                .to receive(:set_action_if_nil).with(nil)
            end
          end
        end
      end

      it "should set metadata" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata).twice
      end

      it "should set the queue start" do
        expect_any_instance_of(Appsignal::Transaction)
          .to receive(:set_http_or_background_queue_start)
      end

      context "with overridden request class and params method" do
        let(:options) { { :request_class => ::Rack::Request, :params_method => :filtered_params } }

        it "should use the overridden request class and params method" do
          request = ::Rack::Request.new(env)
          expect(::Rack::Request).to receive(:new)
            .with(env.merge(:params_method => :filtered_params))
            .at_least(:once)
            .and_return(request)
        end
      end

      after(:error => false) { middleware.call(env) }
      after(:error => true) { expect { middleware.call(env) }.to raise_error(error) }
    end
  end
end
