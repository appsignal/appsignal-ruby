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
          expect(scope_of(root_span)).to eq(["appsignal-ruby-grape", Appsignal::VERSION])
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

      describe "sets non-unique route_param path" do
        def perform
          make_request(env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_action("GET::GrapeExample::Api#/users/:id/")
          expect(last_transaction).to include_metadata("path" => "/users/:id/", "method" => "GET")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.name).to eq("GET::GrapeExample::Api#/users/:id/")
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("GET::GrapeExample::Api#/users/:id/")
          expect(root_span.attributes["appsignal.tag.path"]).to eq("/users/:id/")
          expect(root_span.attributes["appsignal.tag.method"]).to eq("GET")
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
  end
end
