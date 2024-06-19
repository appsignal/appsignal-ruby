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
    let(:env) do
      Rack::MockRequest.env_for("/path", "sinatra.route" => "GET /path", "REQUEST_METHOD" => "GET")
    end
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
    let(:env) do
      Rack::MockRequest.env_for("/path", "sinatra.route" => "GET /path", "REQUEST_METHOD" => "GET")
    end
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
          make_request(env)

          expect(app).to have_received(:call).with(env)
        end
      end

      context "when appsignal is active" do
        context "without an exception" do
          it "reports a process_action.sinatra event" do
            make_request(env)

            expect(last_transaction.to_h).to include(
              "events" => [
                hash_including(
                  "body" => "",
                  "body_format" => Appsignal::EventFormatter::DEFAULT,
                  "count" => 1,
                  "name" => "process_action.sinatra",
                  "title" => ""
                )
              ]
            )
          end
        end

        context "with an error in sinatra.error" do
          let(:error) { ExampleException.new("error message") }
          before do
            env["sinatra.error"] = error
          end

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
            before do
              env.merge!(
                "sinatra.error" => error,
                "sinatra.skip_appsignal_error" => true
              )
            end

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
            let(:env) do
              Rack::MockRequest.env_for("/path", "REQUEST_METHOD" => "GET")
            end

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
              let(:env) do
                Rack::MockRequest.env_for("/path", "REQUEST_METHOD" => "GET")
              end

              it "doesn't set an action name" do
                make_request(env)

                expect(last_transaction.to_h).to include("action" => nil)
              end
            end
          end
        end
      end
    end
  end
end
