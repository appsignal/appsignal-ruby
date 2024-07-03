if DependencyHelper.padrino_present?
  describe "Padrino integration" do
    require "appsignal/integrations/padrino"

    describe Appsignal::Integrations::PadrinoPlugin do
      let(:callbacks) { { :before_load => nil } }
      before do
        Appsignal.config = nil
        allow(Padrino).to receive(:before_load)
          .and_wrap_original do |original_method, *args, &block|
            callbacks[:before_load] = block
            original_method.call(*args, &block)
          end
      end
      after { uninstall_padrino_integration }

      def uninstall_padrino_integration
        expected_middleware = [
          Rack::Events,
          Appsignal::Rack::SinatraBaseInstrumentation
        ]
        Padrino.middleware.delete_if do |middleware|
          expected_middleware.include?(middleware.first)
        end
      end

      context "when already active" do
        before { allow(Appsignal).to receive(:active?).and_return(true) }

        it "does not start AppSignal again" do
          expect(Appsignal::Config).to_not receive(:new)
          expect(Appsignal).to_not receive(:start)

          Appsignal::Integrations::PadrinoPlugin.init
          callbacks[:before_load].call
        end

        it "adds the instrumentation middleware to Sinatra::Base" do
          Appsignal::Integrations::PadrinoPlugin.init
          callbacks[:before_load].call

          middlewares = Padrino.middleware
          expect(middlewares).to include(
            [Rack::Events, [[instance_of(Appsignal::Rack::EventHandler)]], nil]
          )
          expect(middlewares).to include(
            [
              Appsignal::Rack::SinatraBaseInstrumentation,
              [
                :instrument_span_name => "process_action.padrino"
              ],
              nil
            ]
          )
        end
      end

      context "with active config" do
        before do
          ENV["APPSIGNAL_APP_NAME"] = "My Padrino app name"
          ENV["APPSIGNAL_APP_ENV"] = "test"
          ENV["APPSIGNAL_PUSH_API_KEY"] = "my-key"
        end

        it "starts AppSignal on init" do
          expect(Appsignal).to_not be_active

          Appsignal::Integrations::PadrinoPlugin.init
          callbacks[:before_load].call

          expect(Appsignal).to be_active
          middlewares = Padrino.middleware
          expect(middlewares).to include(
            [Rack::Events, [[instance_of(Appsignal::Rack::EventHandler)]], nil]
          )
          expect(middlewares).to include(
            [
              Appsignal::Rack::SinatraBaseInstrumentation,
              [
                :instrument_span_name => "process_action.padrino"
              ],
              nil
            ]
          )
        end

        context "when APPSIGNAL_APP_ENV ENV var is provided" do
          it "uses this as the environment" do
            ENV["APPSIGNAL_APP_ENV"] = "custom"

            Appsignal::Integrations::PadrinoPlugin.init
            callbacks[:before_load].call

            expect(Appsignal.config.env).to eq("custom")
          end
        end

        context "when APPSIGNAL_APP_ENV ENV var is not provided" do
          it "uses the Padrino environment" do
            Appsignal::Integrations::PadrinoPlugin.init
            callbacks[:before_load].call

            expect(Padrino.env.to_s).to eq("test")
            expect(Appsignal.config.env).to eq(Padrino.env.to_s)
          end
        end
      end

      context "when not active" do
        it "does not add the listener middleware to the stack" do
          expect(Appsignal).to_not be_active

          Appsignal::Integrations::PadrinoPlugin.init
          callbacks[:before_load].call

          expect(Appsignal).to_not be_active
          middlewares = Padrino.middleware
          expect(middlewares).to_not include(
            [Rack::Events, [[instance_of(Appsignal::Rack::EventHandler)]], nil]
          )
          expect(middlewares).to_not include(
            [
              Appsignal::Rack::SinatraBaseInstrumentation,
              [
                :request_class => ::Sinatra::Request,
                :instrument_span_name => "process_action.padrino"
              ],
              nil
            ]
          )
        end
      end
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
      before { Appsignal.config = nil }

      describe "routes" do
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

        context "when AppSignal is not active" do
          let(:path) { "/foo" }
          before { app.controllers { get(:foo) { "content" } } }

          it "does not instrument the request" do
            expect do
              expect(response).to match_response(200, "content")
            end.to_not(change { created_transactions.count })
          end
        end

        context "when AppSignal is active" do
          let(:transaction) { http_request_transaction }
          before do
            start_agent
            set_current_transaction(transaction)
          end

          context "with not existing route" do
            let(:path) { "/404" }

            it "instruments the request" do
              expect(response).to match_response(404, /^GET &#x2F;404/)
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
              expect(response).to match_response(200, "Static!")
              expect(last_transaction).to_not have_action
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
              expect(response).to match_response(200, "content")
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
              expect(last_transaction).to have_action("PadrinoTestApp#unknown")
            end
          end

          context "with existing route" do
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
