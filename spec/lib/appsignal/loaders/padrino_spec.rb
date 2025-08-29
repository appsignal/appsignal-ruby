if DependencyHelper.padrino_present?
  describe "Appsignal::Loaders::PadrinoLoader" do
    describe "#on_load" do
      it "registers Padrino default config" do
        load_loader(:padrino)

        expect(Appsignal::Config.loader_defaults).to include(
          :name => :padrino,
          :root_path => Padrino.mounted_root,
          :env => :test,
          :options => {}
        )
      end
    end

    describe "#on_start" do
      let(:callbacks) { { :before_load => nil } }
      before do
        allow(Padrino).to receive(:before_load)
          .and_wrap_original do |original_method, *args, &block|
            callbacks[:before_load] = block
            original_method.call(*args, &block)
          end
      end
      after { uninstall_padrino_integration }

      def uninstall_padrino_integration
        expected_middleware = [
          Appsignal::Rack::EventMiddleware,
          Appsignal::Rack::SinatraBaseInstrumentation
        ]
        Padrino.middleware.delete_if do |middleware|
          expected_middleware.include?(middleware.first)
        end
      end

      it "adds the instrumentation middleware to Padrino" do
        load_loader(:padrino)
        start_loader(:padrino)

        callbacks[:before_load].call

        middlewares = Padrino.middleware
        expect(middlewares).to include(
          [Appsignal::Rack::EventMiddleware, [], nil]
        )
        expect(middlewares).to include(
          [
            Appsignal::Rack::SinatraBaseInstrumentation,
            [
              :instrument_event_name => "process_action.padrino"
            ],
            nil
          ]
        )
      end
    end

    describe "Padrino integration" do
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

        def fetch_body(body)
          if body.respond_to?(:response)
            _, _, nested_body = body.response.to_a
            fetch_body(nested_body)
          elsif body.respond_to?(:to_ary)
            body.to_ary
          else
            body
          end
        end

        RSpec::Matchers.define :match_response do |expected_status, expected_body|
          match do |response|
            status, _headers, potential_body = response
            body = fetch_body(potential_body)

            matches_body =
              if expected_body.is_a?(Regexp)
                body.join =~ expected_body
              else
                body == [expected_body].compact
              end
            status == expected_status && matches_body
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
