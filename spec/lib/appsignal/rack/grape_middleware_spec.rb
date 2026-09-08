if DependencyHelper.grape_present?
  require "appsignal/rack/grape_middleware"

  describe Appsignal::Rack::GrapeMiddleware do
    let(:app) do
      Class.new(::Grape::API) do
        use Appsignal::Rack::GrapeMiddleware
        format :json
        post :ping do
          { :message => "Hello world!" }
        end
      end
    end
    let(:env) do
      Rack::MockRequest.env_for("/ping", :method => "POST")
    end
    before { stub_const("GrapeExample::Api", app) }

    def make_request(env)
      app.call(env)
    end

    def make_request_with_exception(env, exception_class, exception_message)
      expect do
        app.call(env)
      end.to raise_error(exception_class, exception_message)
    end

    let(:expected_method) { "GET" }

    # Where the two Grape majors report a route differently, each gets its own
    # "in Grape 3" and "in Grape 4" examples rather than one example with a
    # version-dependent expectation. The spec coverage audit works per source
    # line and asks only that some build matrix combination runs each one, so
    # examples shared between the two majors would let a Grape 4 run stand in
    # for a Grape 3 one that the matrix had stopped running. These helpers hold
    # the assertions so that only the expected path is written out twice.
    def expect_reported_route_in_agent_mode
      expect(last_transaction).to have_action(expected_action)
      expect(last_transaction).to include_metadata(
        "path" => expected_path,
        "method" => expected_method
      )
    end

    def expect_reported_route_in_collector_mode
      expect(root_span.name).to eq(expected_action)
      expect(root_span.attributes["appsignal.action_name"]).to eq(expected_action)
      expect(root_span.attributes["appsignal.tag.path"]).to eq(expected_path)
      expect(root_span.attributes["appsignal.tag.method"]).to eq(expected_method)
    end

    context "with error" do
      let(:app) do
        Class.new(::Grape::API) do
          use Appsignal::Rack::GrapeMiddleware
          format :json
          post :ping do
            raise ExampleException, "error message"
          end
        end
      end

      describe "sets the error" do
        def perform
          make_request_with_exception(env, ExampleException, "error message")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_error("ExampleException", "error message")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("error message")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end

      context "with env['grape.skip_appsignal_error'] = true" do
        let(:app) do
          Class.new(::Grape::API) do
            use Appsignal::Rack::GrapeMiddleware
            format :json
            post :ping do
              env["grape.skip_appsignal_error"] = true
              raise ExampleException, "error message"
            end
          end
        end

        describe "does not add the error" do
          def perform
            make_request_with_exception(env, ExampleException, "error message")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to_not have_error
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(exception_events).to be_empty
          end
        end
      end
    end

    context "with route" do
      let(:app) do
        Class.new(::Grape::API) do
          use Appsignal::Rack::GrapeMiddleware
          route([:get, :post], "hello") do
            "Hello!"
          end
        end
      end
      let(:env) do
        Rack::MockRequest.env_for("/hello", :method => "GET")
      end

      describe "sets non-unique route path" do
        def perform
          make_request(env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_action("GET::GrapeExample::Api#/hello")
          expect(last_transaction).to include_metadata("path" => "/hello", "method" => "GET")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.name).to eq("GET::GrapeExample::Api#/hello")
          expect(root_span.kind).to eq(:server)
          expect(scope_of(root_span)).to eq(["appsignal-ruby/grape", Appsignal::VERSION])
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("GET::GrapeExample::Api#/hello")
          expect(root_span.attributes["appsignal.tag.path"]).to eq("/hello")
          expect(root_span.attributes["appsignal.tag.method"]).to eq("GET")
        end
      end
    end

    context "with route_param" do
      let(:app) do
        Class.new(::Grape::API) do
          use Appsignal::Rack::GrapeMiddleware
          format :json
          resource :users do
            route_param :id do
              get do
                { :name => "Tom" }
              end
            end
          end
        end
      end
      let(:env) do
        Rack::MockRequest.env_for("/users/123", :method => "GET")
      end

      let(:expected_action) { "GET::GrapeExample::Api##{expected_path}" }

      def perform
        make_request(env)
      end

      # The endpoint declares no path of its own, so the namespace is reported
      # with the endpoint's default "/" path appended.
      describe "in Grape 3", :if => !DependencyHelper.grape4_present? do
        let(:expected_path) { "/users/:id/" }

        it "sets non-unique route_param path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets non-unique route_param path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end

      # The route's own template has no trailing slash.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/users/:id" }

        it "sets non-unique route_param path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets non-unique route_param path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end
    end

    context "with namespaced path" do
      shared_examples "sets the namespaced path" do |action|
        describe "sets namespaced path" do
          def perform
            make_request(env)
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to have_action(action)
            expect(last_transaction).to include_metadata(
              "path" => "/v1/beta/ping",
              "method" => "POST"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.name).to eq(action)
            expect(root_span.attributes["appsignal.action_name"]).to eq(action)
            expect(root_span.attributes["appsignal.tag.path"]).to eq("/v1/beta/ping")
            expect(root_span.attributes["appsignal.tag.method"]).to eq("POST")
          end
        end
      end

      context "with symbols" do
        let(:app) do
          Class.new(::Grape::API) do
            use Appsignal::Rack::GrapeMiddleware
            format :json
            namespace :v1 do
              namespace :beta do
                post :ping do
                  { :message => "Hello namespaced world!" }
                end
              end
            end
          end
        end
        let(:env) do
          Rack::MockRequest.env_for("/v1/beta/ping", :method => "POST")
        end

        include_examples "sets the namespaced path", "POST::GrapeExample::Api#/v1/beta/ping"
      end

      context "with strings" do
        context "without / prefix" do
          let(:app) do
            Class.new(::Grape::API) do
              use Appsignal::Rack::GrapeMiddleware
              format :json
              namespace "v1" do
                namespace "beta" do
                  post "ping" do
                    { :message => "Hello namespaced world!" }
                  end
                end
              end
            end
          end
          let(:env) do
            Rack::MockRequest.env_for("/v1/beta/ping", :method => "POST")
          end

          include_examples "sets the namespaced path", "POST::GrapeExample::Api#/v1/beta/ping"
        end

        context "with / prefix" do
          let(:app) do
            Class.new(::Grape::API) do
              use Appsignal::Rack::GrapeMiddleware
              format :json
              namespace "/v1" do
                namespace "/beta" do
                  post "/ping" do
                    { :message => "Hello namespaced world!" }
                  end
                end
              end
            end
          end
          let(:env) do
            Rack::MockRequest.env_for("/v1/beta/ping", :method => "POST")
          end

          include_examples "sets the namespaced path", "POST::GrapeExample::Api#/v1/beta/ping"
        end
      end
    end

    context "with a prefix and a path version" do
      let(:app) do
        Class.new(::Grape::API) do
          use Appsignal::Rack::GrapeMiddleware
          format :json
          prefix "api"
          version "v2", :using => :path
          namespace :things do
            get :list do
              { :message => "Hello prefixed world!" }
            end
          end
        end
      end
      let(:env) do
        Rack::MockRequest.env_for("/api/v2/things/list", :method => "GET")
      end
      let(:expected_action) { "GET::GrapeExample::Api##{expected_path}" }

      def perform
        make_request(env)
      end

      # Only the endpoint's namespace and its own path are reported.
      describe "in Grape 3", :if => !DependencyHelper.grape4_present? do
        let(:expected_path) { "/things/list" }

        it "sets the prefixed and versioned path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets the prefixed and versioned path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end

      # The route's template also carries the API prefix and the path
      # version.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/api/:version/things/list" }

        it "sets the prefixed and versioned path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets the prefixed and versioned path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end
    end

    context "with a mounted API" do
      let(:mounted_app) do
        Class.new(::Grape::API) do
          namespace :inner do
            get :thing do
              { :message => "Hello mounted world!" }
            end
          end
        end
      end
      let(:app) do
        mounted = mounted_app
        Class.new(::Grape::API) do
          use Appsignal::Rack::GrapeMiddleware
          format :json
          mount mounted => "/mnt"
        end
      end
      let(:env) do
        Rack::MockRequest.env_for("/mnt/inner/thing", :method => "GET")
      end
      before { stub_const("GrapeExample::Mounted", mounted_app) }
      # The action names the mounted API rather than the one it is mounted in.
      let(:expected_action) { "GET::GrapeExample::Mounted##{expected_path}" }

      def perform
        make_request(env)
      end

      # Only the endpoint's namespace and its own path are reported.
      describe "in Grape 3", :if => !DependencyHelper.grape4_present? do
        let(:expected_path) { "/inner/thing" }

        it "sets the mounted path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets the mounted path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end

      # The route's template also carries the mount point.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/mnt/inner/thing" }

        it "sets the mounted path in agent mode", :agent_mode do
          start_agent
          perform

          expect_reported_route_in_agent_mode
        end

        it "sets the mounted path in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect_reported_route_in_collector_mode
        end
      end
    end
  end
end
