if DependencyHelper.padrino_present?
  describe "Padrino integration" do
    require "appsignal/integrations/padrino"

    before do
      allow(Appsignal).to receive(:active?).and_return(true)
      allow(Appsignal).to receive(:start).and_return(true)
      allow(Appsignal).to receive(:start_logger).and_return(true)
    end

    describe Appsignal::Integrations::PadrinoPlugin do
      it "starts AppSignal on init" do
        expect(Appsignal).to receive(:start)
      end

      it "starts the logger on init" do
        expect(Appsignal).to receive(:start_logger)
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

      describe "routes" do
        let(:transaction) do
          instance_double "Appsignal::Transaction",
            :set_http_or_background_action => nil,
            :set_http_or_background_queue_start => nil,
            :set_metadata => nil,
            :set_action => nil,
            :set_action_if_nil => nil,
            :set_error => nil,
            :start_event => nil,
            :finish_event => nil,
            :complete => nil
        end
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
        before do
          allow(Appsignal::Transaction).to receive(:create).and_return(transaction)
          allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
        end

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
          expect(Appsignal::Transaction).to receive(:create).with(
            kind_of(String),
            Appsignal::Transaction::HTTP_REQUEST,
            request_kind
          ).and_return(transaction)

          expect(Appsignal).to receive(:instrument)
            .at_least(:once)
            .with("process_action.padrino")
            .and_call_original
          expect(transaction).to receive(:set_metadata).with("path", path)
          expect(transaction).to receive(:set_metadata).with("method", "GET")
          expect(transaction).to receive(:complete)
        end

        def expect_no_transaction_to_be_created
          expect(Appsignal::Transaction).to_not receive(:create)
          expect(Appsignal).to_not receive(:instrument)
        end

        context "when AppSignal is not active" do
          before { allow(Appsignal).to receive(:active?).and_return(false) }
          let(:path) { "/foo" }
          before { app.controllers { get(:foo) { "content" } } }
          after { expect(response).to match_response(200, "content") }

          it "does not instrument the request" do
            expect_no_transaction_to_be_created
          end
        end

        context "when AppSignal is active" do
          context "with not existing route" do
            let(:path) { "/404" }

            it "instruments the request" do
              expect_a_transaction_to_be_created
              # Uses path for action name
              expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp#unknown")
              expect(response).to match_response(404, /^GET &#x2F;404/)
            end
          end

          context "when Sinatra tells us it's a static file" do
            let(:path) { "/static" }
            before do
              env["sinatra.static_file"] = true
              app.controllers { get(:static) { "Static!" } }
            end
            after { expect(response).to match_response(200, "Static!") }

            it "does not instrument the request" do
              expect_no_transaction_to_be_created
            end
          end

          # Older Padrino versions don't support `action` (v11.0+)
          context "without #action on Sinatra::Request" do
            let(:path) { "/my_original_path/10" }
            before do
              allow_any_instance_of(Sinatra::Request).to receive(:action).and_return(nil)
              app.controllers { get(:my_original_path, :with => :id) { "content" } }
            end
            after { expect(response).to match_response(200, "content") }

            it "falls back on Sinatra::Request#route_obj.original_path" do
              expect_a_transaction_to_be_created
              expect(transaction)
                .to receive(:set_action_if_nil).with("PadrinoTestApp:/my_original_path/:id")
            end
          end

          context "without Sinatra::Request#route_obj.original_path" do
            let(:path) { "/my_original_path" }
            before do
              allow_any_instance_of(Sinatra::Request).to receive(:action).and_return(nil)
              allow_any_instance_of(Sinatra::Request).to receive(:route_obj).and_return(nil)
              app.controllers { get(:my_original_path) { "content" } }
            end
            after { expect(response).to match_response(200, "content") }

            it "falls back on app name" do
              expect_a_transaction_to_be_created
              expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp#unknown")
            end
          end

          context "with existing route" do
            context "with an exception in the controller" do
              let(:path) { "/exception" }
              before do
                app.controllers { get(:exception) { raise ExampleException } }
                expect_a_transaction_to_be_created
              end
              after do
                expect { response }.to raise_error(ExampleException)
              end

              it "sets the action name based on the app name and action name" do
                expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp:#exception")
              end

              it "sets the error on the transaction" do
                expect(transaction).to receive(:set_error).with(ExampleException)
              end
            end

            context "without an exception in the controller" do
              let(:path) { "/" }
              after { expect(response).to match_response(200, "content") }

              context "with action name as symbol" do
                context "with :index helper" do
                  before do
                    # :index == "/"
                    app.controllers { get(:index) { "content" } }
                  end

                  it "sets the action with the app name and action name" do
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp:#index")
                  end
                end

                context "with custom action name" do
                  let(:path) { "/foo" }
                  before do
                    app.controllers { get(:foo) { "content" } }
                  end

                  it "sets the action with the app name and action name" do
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp:#foo")
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
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp:#/")
                  end
                end

                context "with custom path" do
                  let(:path) { "/foo" }
                  before do
                    app.controllers { get("/foo") { "content" } }
                  end

                  it "sets the action with the app name and action path" do
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil).with("PadrinoTestApp:#/foo")
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
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil)
                      .with("PadrinoTestApp:my_controller#index")
                  end
                end

                context "with controller as path" do
                  before do
                    # :index == "/"
                    app.controllers("/my_controller") { get(:index) { "content" } }
                  end

                  it "sets the action with the app name, controller name and action path" do
                    expect_a_transaction_to_be_created
                    expect(transaction).to receive(:set_action_if_nil)
                      .with("PadrinoTestApp:/my_controller#index")
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
