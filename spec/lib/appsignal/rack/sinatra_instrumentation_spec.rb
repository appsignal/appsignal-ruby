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
        expect { make_request(env) }.to_not(change { created_transactions.count })
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
    let(:env) { { "sinatra.route" => "GET /path", :path => "/path", :method => "GET" } }
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

      context "when appsignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not instrument requests" do
          expect { make_request(env) }.to_not(change { created_transactions.count })
        end

        it "calls the next middleware in the stack" do
          expect(app).to receive(:call).with(env)
          make_request(env)
        end
      end

      context "when appsignal is active" do
        it "calls the next middleware in the stack" do
          expect(app).to receive(:call).with(env)
          make_request(env)
        end

        context "without an error" do
          before do
            expect { make_request(env) }.to(change { created_transactions.count }.by(1))
          end

          it "creates a transaction without an error" do
            expect(last_transaction.to_h).to include(
              "namespace" => Appsignal::Transaction::HTTP_REQUEST,
              "action" => "GET /path",
              "error" => nil,
              "metadata" => { "path" => "" }
            )
          end

          it "completes the transaction" do
            expect(last_transaction).to be_completed
          end
        end

        context "with an error" do
          let(:error) { ExampleException.new("error message") }
          before do
            allow(app).to receive(:call).and_raise(error)
            expect { make_request_with_error(env, error) }
              .to(change { created_transactions.count }.by(1))
          end

          it "creates and completes a transaction and records the exception" do
            expect(last_transaction.to_h).to include(
              "namespace" => Appsignal::Transaction::HTTP_REQUEST,
              "action" => "GET /path",
              "error" => hash_including(
                "name" => "ExampleException",
                "message" => "error message"
              )
            )
          end

          it "completes the transaction" do
            expect(last_transaction).to be_completed
          end
        end

        context "with an error in sinatra.error" do
          let(:error) { ExampleException.new("error message") }
          let(:env) { { "sinatra.error" => error } }

          context "when raise_errors is off" do
            let(:settings) { double(:raise_errors => false) }

            it "record the error" do
              expect { make_request(env) }
                .to(change { created_transactions.count }.by(1))

              expect(last_transaction.to_h).to include(
                "error" => hash_including(
                  "name" => "ExampleException",
                  "message" => "error message"
                )
              )
            end
          end

          context "when raise_errors is on" do
            let(:settings) { double(:raise_errors => true) }

            it "does not record the error" do
              expect { make_request(env) }
                .to(change { created_transactions.count }.by(1))

              expect(last_transaction.to_h).to include("error" => nil)
            end
          end

          context "if sinatra.skip_appsignal_error is set" do
            let(:env) { { "sinatra.error" => error, "sinatra.skip_appsignal_error" => true } }

            it "does not record the error" do
              expect { make_request(env) }
                .to(change { created_transactions.count }.by(1))

              expect(last_transaction.to_h).to include("error" => nil)
            end
          end
        end

        describe "action name" do
          it "sets the action to the request method and path" do
            make_request(env)

            expect(last_transaction.to_h).to include("action" => "GET /path")
          end

          context "without 'sinatra.route' env" do
            let(:env) { { :path => "/path", :method => "GET" } }

            it "doesn't set an action name" do
              make_request(env)

              expect(last_transaction.to_h).to include("action" => nil)
            end
          end

          context "with mounted modular application" do
            before { env["SCRIPT_NAME"] = "/api" }

            it "sets the action name with an application prefix path" do
              make_request(env)

              expect(last_transaction.to_h).to include("action" => "GET /api/path")
            end

            context "without 'sinatra.route' env" do
              let(:env) { { :path => "/path", :method => "GET" } }

              it "doesn't set an action name" do
                make_request(env)

                expect(last_transaction.to_h).to include("action" => nil)
              end
            end
          end
        end

        context "metadata" do
          let(:env) { { "PATH_INFO" => "/some/path", "REQUEST_METHOD" => "GET" } }

          it "sets metadata from the environment" do
            make_request(env)

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
          let(:options) do
            { :request_class => FilteredRequest, :params_method => :filtered_params }
          end

          it "uses the overridden request class and params method to fetch params" do
            make_request(env)

            expect(last_transaction.to_h).to include(
              "sample_data" => hash_including(
                "params" => { "abc" => "123" }
              )
            )
          end
        end

        context "with parent instrumentation" do
          before do
            env["PATH_INFO"] = "/some/path"
            env["REQUEST_METHOD"] = "GET"
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = http_request_transaction
            make_request(env)
          end

          it "uses the existing transaction" do
            expect { make_request(env) }.to_not(change { created_transactions.count })
          end

          it "sets metadata on the transaction" do
            expect(env[Appsignal::Rack::APPSIGNAL_TRANSACTION].to_h).to include(
              "namespace" => Appsignal::Transaction::HTTP_REQUEST,
              "action" => "GET /path",
              "metadata" => {
                "method" => "GET",
                "path" => "/some/path"
              }
            )
          end

          it "doesn't complete the existing transaction" do
            expect(env[Appsignal::Rack::APPSIGNAL_TRANSACTION]).to_not be_completed
          end
        end
      end
    end
  end
end
