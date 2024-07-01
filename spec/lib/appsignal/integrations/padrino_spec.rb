if DependencyHelper.padrino_present?
  describe "Padrino integration" do
    require "appsignal/integrations/padrino"

    describe Appsignal::Integrations::PadrinoPlugin do
      it "starts AppSignal on init" do
        expect(Appsignal).to receive(:start)
      end

      context "when not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not add the listener middleware to the stack" do
          expect(Padrino).to_not receive(:use)
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is provided" do
        it "uses this as the environment" do
          ENV["APPSIGNAL_APP_ENV"] = "custom"

          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::PadrinoPlugin.init

          expect(Appsignal.config.env).to eq("custom")
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is not provided" do
        it "uses the Padrino environment" do
          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::PadrinoPlugin.init

          expect(Padrino.env.to_s).to eq("test")
          expect(Appsignal.config.env).to eq(Padrino.env.to_s)
        end
      end

      after { Appsignal::Integrations::PadrinoPlugin.init }
    end

    describe Padrino::Routing::InstanceMethods do
      class PadrinoClassWithRouter
        include Padrino::Routing
      end

      let(:base)     { double }
      let(:router)   { PadrinoClassWithRouter.new }
      let(:env)      { {} }
      # TODO: use an instance double
      let(:settings) { double(:name => "TestApp") }
      around { |example| keep_transactions { example.run } }

      describe "routes" do
        let(:request_kind) { kind_of(Sinatra::Request) }
        let(:env) do
          {
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => path,
            "REQUEST_PATH" => path,
            "rack.input" => StringIO.new
          }
        end
        let(:app) do
          Class.new(Padrino::Application) do
            def self.name
              "PadrinoTestApp"
            end
          end
        end
        let(:response) { app.call(env) }

        RSpec::Matchers.define :match_response do |expected_status, expected_content|
          match do |response|
            status, _headers, content = response
            matches_content =
              if expected_content.is_a?(Regexp)
                content.join =~ expected_content
              else
                content == [expected_content].compact
              end
            status == expected_status && matches_content
          end
        end

        def expect_a_transaction_to_be_created
          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to include_metadata(
            "path" => path,
            "method" => "GET"
          )
          expect(transaction).to include_event("name" => "process_action.padrino")
          expect(transaction).to be_completed
        end

        context "when AppSignal is not active" do
          before { allow(Appsignal).to receive(:active?).and_return(false) }
          let(:path) { "/foo" }
          before { app.controllers { get(:foo) { "content" } } }

          it "does not instrument the request" do
            expect do
              expect(response).to match_response(200, "content")
            end.to_not(change { created_transactions.count })
          end
        end

        context "when AppSignal is active" do
          before { start_agent }

          context "with not existing route" do
            let(:path) { "/404" }

            it "instruments the request" do
              expect(response).to match_response(404, /^GET &#x2F;404/)

              expect_a_transaction_to_be_created
              # Uses path for action name
              expect(last_transaction).to have_action("PadrinoTestApp#unknown")
            end
          end

          context "when Sinatra tells us it's a static file" do
            let(:path) { "/static" }
            before do
              env["sinatra.static_file"] = true
              app.controllers { get(:static) { "Static!" } }
            end

            it "does not instrument the request" do
              expect do
                expect(response).to match_response(200, "Static!")
              end.to_not(change { created_transactions.count })
            end
          end

          # Older Padrino versions don't support `action` (v11.0+)
          context "without #action on Sinatra::Request" do
            let(:path) { "/my_original_path/10" }
            before do
              allow_any_instance_of(Sinatra::Request).to receive(:action).and_return(nil)
              app.controllers { get(:my_original_path, :with => :id) { "content" } }
            end

            it "falls back on Sinatra::Request#route_obj.original_path" do
              expect do
                expect(response).to match_response(200, "content")
              end.to(change { created_transactions.count }.by(1))

              expect_a_transaction_to_be_created
              expect(last_transaction).to have_action("PadrinoTestApp:/my_original_path/:id")
            end
          end

          context "without Sinatra::Request#route_obj.original_path" do
            let(:path) { "/my_original_path" }
            before do
              allow_any_instance_of(Sinatra::Request).to receive(:action).and_return(nil)
              allow_any_instance_of(Sinatra::Request).to receive(:route_obj).and_return(nil)
              app.controllers { get(:my_original_path) { "content" } }
            end

            it "falls back on app name" do
              expect(response).to match_response(200, "content")
              expect_a_transaction_to_be_created
              expect(last_transaction).to have_action("PadrinoTestApp#unknown")
            end
          end

          context "with existing route" do
            context "with an exception in the controller" do
              let(:path) { "/exception" }
              before do
                app.controllers { get(:exception) { raise ExampleException, "error message" } }
                expect { response }.to raise_error(ExampleException, "error message")
                expect_a_transaction_to_be_created
              end

              it "sets the action name based on the app name and action name" do
                expect(last_transaction).to have_action("PadrinoTestApp:#exception")
              end

              it "sets the error on the transaction" do
                expect(last_transaction).to have_error("ExampleException", "error message")
              end
            end

            context "without an exception in the controller" do
              let(:path) { "/" }
              def make_request
                expect(response).to match_response(200, "content")
              end

              context "with action name as symbol" do
                context "with :index helper" do
                  before do
                    # :index == "/"
                    app.controllers { get(:index) { "content" } }
                  end

                  it "sets the action with the app name and action name" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:#index")
                  end
                end

                context "with custom action name" do
                  let(:path) { "/foo" }
                  before do
                    app.controllers { get(:foo) { "content" } }
                  end

                  it "sets the action with the app name and action name" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:#foo")
                  end
                end
              end

              context "with an action defined with a path" do
                context "with root path" do
                  before do
                    # :index == "/"
                    app.controllers { get("/") { "content" } }
                  end

                  it "sets the action with the app name and action path" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:#/")
                  end
                end

                context "with custom path" do
                  let(:path) { "/foo" }
                  before do
                    app.controllers { get("/foo") { "content" } }
                  end

                  it "sets the action with the app name and action path" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:#/foo")
                  end
                end
              end

              context "with controller" do
                let(:path) { "/my_controller" }

                context "with controller as name" do
                  before do
                    # :index == "/"
                    app.controllers(:my_controller) { get(:index) { "content" } }
                  end

                  it "sets the action with the app name, controller name and action name" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:my_controller#index")
                  end
                end

                context "with controller as path" do
                  before do
                    # :index == "/"
                    app.controllers("/my_controller") { get(:index) { "content" } }
                  end

                  it "sets the action with the app name, controller name and action path" do
                    make_request
                    expect_a_transaction_to_be_created
                    expect(last_transaction).to have_action("PadrinoTestApp:/my_controller#index")
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
