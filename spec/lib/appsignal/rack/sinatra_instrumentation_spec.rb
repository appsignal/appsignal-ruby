if DependencyHelper.sinatra_present?
  require "appsignal/integrations/sinatra"

  module SinatraRequestHelpers
    def make_request(env)
      middleware.call(env)
    end

    def make_request_with_error(env, error)
      expect { middleware.call(env) }.to raise_error(error)
    end
  end

  describe Appsignal::Rack::SinatraInstrumentation do
    include SinatraRequestHelpers

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) { { "sinatra.route" => "GET /", :path => "/", :method => "GET" } }
    let(:middleware) { Appsignal::Rack::SinatraInstrumentation.new(app) }

    before(:context) { start_agent }
    around do |example|
      keep_transactions { example.run }
    end

    describe "#call" do
      before { allow(middleware).to receive(:raw_payload).and_return({}) }

      it "doesn't instrument requests" do
        make_request(env)
        expect(created_transactions.count).to eq(0)
      end
    end

    describe ".settings" do
      subject { middleware.settings }

      it "returns the app's settings" do
        expect(subject).to eq(app.settings)
      end
    end
  end

  describe Appsignal::Rack::SinatraBaseInstrumentation do
    include SinatraRequestHelpers

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) { { "sinatra.route" => "GET /", :path => "/", :method => "GET" } }
    let(:options) { {} }
    let(:middleware) { Appsignal::Rack::SinatraBaseInstrumentation.new(app, options) }

    before(:context) { start_agent }
    around do |example|
      keep_transactions { example.run }
    end

    describe "#initialize" do
      context "with no settings method in the Sinatra app" do
        let(:app) { double(:call => true) }

        it "does not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with no raise_errors setting in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double) }

        it "does not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned off in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => false)) }

        it "raises errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned on in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => true)) }

        it "raises errors" do
          expect(middleware.raise_errors_on).to be(true)
        end
      end
    end

    describe "#call" do
      before { allow(middleware).to receive(:raw_payload).and_return({}) }

      context "when appsignal is active" do
        it "instruments requests" do
          expect(middleware).to receive(:call_with_appsignal_monitoring).with(env)
        end
      end

      context "when appsignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not instrument requests" do
          expect(created_transactions.count).to eq(0)
        end

        it "calls the next middleware in the stack" do
          expect(app).to receive(:call).with(env)
        end
      end

      after { make_request(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      context "without an error" do
        it "creates a transaction" do
          expect(app).to receive(:call).with(env)

          make_request(env)

          expect(created_transactions.count).to eq(1)
          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::HTTP_REQUEST,
            "action" => "GET /",
            "error" => nil,
            "metadata" => { "path" => "" }
          )
        end
      end

      context "with an error" do
        let(:error) { ExampleException }
        let(:app) do
          double.tap do |d|
            allow(d).to receive(:call).and_raise(error)
            allow(d).to receive(:settings).and_return(settings)
          end
        end

        it "records the exception" do
          make_request_with_error(env, error)

          expect(created_transactions.count).to eq(1)
          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::HTTP_REQUEST,
            "action" => "GET /",
            "error" => hash_including(
              "name" => "ExampleException",
              "message" => "ExampleException"
            )
          )
        end
      end

      context "with an error in sinatra.error" do
        let(:error) { ExampleException.new }
        let(:env) { { "sinatra.error" => error } }

        context "when raise_errors is off" do
          let(:settings) { double(:raise_errors => false) }

          it "record the error" do
            make_request(env)

            expect(created_transactions.count).to eq(1)
            expect(last_transaction.to_h).to include(
              "error" => hash_including(
                "name" => "ExampleException",
                "message" => "ExampleException"
              )
            )
          end
        end

        context "when raise_errors is on" do
          let(:settings) { double(:raise_errors => true) }

          it "does not record the error" do
            make_request(env)

            expect(created_transactions.count).to eq(1)
            expect(last_transaction.to_h).to include("error" => nil)
          end
        end

        context "if sinatra.skip_appsignal_error is set" do
          let(:env) { { "sinatra.error" => error, "sinatra.skip_appsignal_error" => true } }

          it "does not record the error" do
            make_request(env)

            expect(created_transactions.count).to eq(1)
            expect(last_transaction.to_h).to include("error" => nil)
          end
        end
      end

      describe "action name" do
        it "sets the action" do
          make_request(env)

          expect(created_transactions.count).to eq(1)
          expect(last_transaction.to_h).to include("action" => "GET /")
        end

        context "without 'sinatra.route' env" do
          let(:env) { { :path => "/", :method => "GET" } }

          it "doesn't set an action name" do
            make_request(env)

            expect(created_transactions.count).to eq(1)
            expect(last_transaction.to_h).to include("action" => nil)
          end
        end

        context "with mounted modular application" do
          before { env["SCRIPT_NAME"] = "/api" }

          it "should call set_action with an application prefix path" do
            make_request(env)

            expect(created_transactions.count).to eq(1)
            expect(last_transaction.to_h).to include("action" => "GET /api/")
          end

          context "without 'sinatra.route' env" do
            let(:env) { { :path => "/", :method => "GET" } }

            it "doesn't set an action name" do
              make_request(env)

              expect(created_transactions.count).to eq(1)
              expect(last_transaction.to_h).to include("action" => nil)
            end
          end
        end
      end

      context "metadata" do
        let(:env) { { "PATH_INFO" => "/some/path", "REQUEST_METHOD" => "GET" } }

        it "sets metadata from the environment" do
          make_request(env)

          expect(created_transactions.count).to eq(1)
          expect(last_transaction.to_h).to include(
            "metadata" => {
              "method" => "GET",
              "path" => "/some/path"
            },
            "sample_data" => hash_including(
              "environment" => hash_including(
                "REQUEST_METHOD" => "GET",
                "PATH_INFO" => "/some/path"
              )
            )
          )
        end
      end

      context "with queue start" do
        let(:queue_start_time) { fixed_time * 1_000 }
        let(:env) do
          { "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}" } # in milliseconds
        end

        it "sets the queue start" do
          make_request(env)
          expect(last_transaction.ext.queue_start).to eq(queue_start_time)
        end
      end

      class FilteredRequest
        def initialize(_args) # rubocop:disable Style/RedundantInitialize
        end

        def path
          "/static/path"
        end

        def request_method
          "GET"
        end

        def filtered_params
          { "abc" => "123" }
        end
      end

      context "with overridden request class and params method" do
        let(:options) { { :request_class => FilteredRequest, :params_method => :filtered_params } }

        it "uses the overridden request class and params method to fetch params" do
          make_request(env)

          expect(created_transactions.count).to eq(1)
          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "params" => { "abc" => "123" }
            )
          )
        end
      end
    end
  end
end
