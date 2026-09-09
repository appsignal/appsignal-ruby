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
    let(:transaction) { http_request_transaction }
    before do
      stub_const("GrapeExample::Api", app)
      start_agent
    end
    around do |example|
      keep_transactions { example.run }
    end

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
    # version-dependent expectation. That way a build matrix that stopped
    # running one of the two majors leaves examples that nothing runs, instead
    # of examples that quietly stop checking that major.
    def expect_reported_route
      expect(last_transaction).to have_action(expected_action)
      expect(last_transaction).to include_metadata(
        "path" => expected_path,
        "method" => expected_method
      )
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

      it "sets the error" do
        make_request_with_exception(env, ExampleException, "error message")

        expect(last_transaction).to have_error("ExampleException", "error message")
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

        it "does not add the error" do
          make_request_with_exception(env, ExampleException, "error message")

          expect(last_transaction).to_not have_error
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

      it "sets non-unique route path" do
        make_request(env)

        expect(last_transaction).to have_action("GET::GrapeExample::Api#/hello")
        expect(last_transaction).to include_metadata("path" => "/hello", "method" => "GET")
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

        it "sets non-unique route_param path" do
          perform

          expect_reported_route
        end
      end

      # The route's own template has no trailing slash.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/users/:id" }

        it "sets non-unique route_param path" do
          perform

          expect_reported_route
        end
      end
    end

    context "with namespaced path" do
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

        it "sets namespaced path" do
          make_request(env)

          expect(last_transaction).to have_action("POST::GrapeExample::Api#/v1/beta/ping")
          expect(last_transaction).to include_metadata("path" => "/v1/beta/ping",
            "method" => "POST")
        end
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

          it "sets namespaced path" do
            make_request(env)

            expect(last_transaction).to have_action("POST::GrapeExample::Api#/v1/beta/ping")
            expect(last_transaction).to include_metadata(
              "path" => "/v1/beta/ping",
              "method" => "POST"
            )
          end
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

          it "sets namespaced path" do
            make_request(env)

            expect(last_transaction).to have_action("POST::GrapeExample::Api#/v1/beta/ping")
            expect(last_transaction).to include_metadata("path" => "/v1/beta/ping",
              "method" => "POST")
          end
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

        it "sets the prefixed and versioned path" do
          perform

          expect_reported_route
        end
      end

      # The route's template also carries the API prefix and the path
      # version.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/api/:version/things/list" }

        it "sets the prefixed and versioned path" do
          perform

          expect_reported_route
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

        it "sets the mounted path" do
          perform

          expect_reported_route
        end
      end

      # The route's template also carries the mount point.
      describe "in Grape 4", :if => DependencyHelper.grape4_present? do
        let(:expected_path) { "/mnt/inner/thing" }

        it "sets the mounted path" do
          perform

          expect_reported_route
        end
      end
    end
  end
end
