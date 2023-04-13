if DependencyHelper.grape_present?
  require "appsignal/integrations/grape"

  describe Appsignal::Grape::Middleware do
    let(:app) do
      Class.new(::Grape::API) do
        format :json
        post :ping do
          { :message => "Hello world!" }
        end
      end
    end
    let(:api_endpoint) { app.endpoints.first }
    let(:env) do
      http_request_env_with_data \
        "api.endpoint" => api_endpoint,
        "REQUEST_METHOD" => "POST",
        :path => "/ping"
    end
    let(:middleware) { Appsignal::Grape::Middleware.new(api_endpoint) }
    around do |example|
      GrapeExample = Module.new
      GrapeExample.send(:const_set, :Api, app)
      example.run
      Object.send(:remove_const, :GrapeExample)
    end

    describe "#call" do
      context "when AppSignal is not active" do
        before(:context) do
          Appsignal.config = nil
          Appsignal::Hooks.load_hooks
        end

        it "creates no transaction" do
          expect(Appsignal::Transaction).to_not receive(:create)
        end

        it "calls the endpoint normally" do
          expect(api_endpoint).to receive(:call).with(env)
        end

        after { middleware.call(env) }
      end

      context "when AppSignal is active" do
        let(:transaction) { http_request_transaction }
        before :context do
          Appsignal.config = project_fixture_config
          expect(Appsignal.active?).to be_truthy
        end
        before do
          expect(Appsignal::Transaction).to receive(:create).with(
            kind_of(String),
            Appsignal::Transaction::HTTP_REQUEST,
            kind_of(::Rack::Request)
          ).and_return(transaction)
        end

        context "without error" do
          it "calls the endpoint" do
            expect(api_endpoint).to receive(:call).with(env)
          end

          it "sets metadata" do
            expect(transaction).to receive(:set_http_or_background_queue_start)
            expect(transaction).to receive(:set_action_if_nil).with("POST::GrapeExample::Api#/ping")
            expect(transaction).to receive(:set_metadata).with("path", "/ping")
            expect(transaction).to receive(:set_metadata).with("method", "POST")
          end

          after { middleware.call(env) }
        end

        context "with error" do
          let(:app) do
            Class.new(::Grape::API) do
              format :json
              post :ping do
                raise ExampleException
              end
            end
          end

          it "sets metadata" do
            expect(transaction).to receive(:set_http_or_background_queue_start)
            expect(transaction).to receive(:set_action_if_nil).with("POST::GrapeExample::Api#/ping")
            expect(transaction).to receive(:set_metadata).with("path", "/ping")
            expect(transaction).to receive(:set_metadata).with("method", "POST")
          end

          it "sets the error" do
            expect(transaction).to receive(:set_error).with(kind_of(ExampleException))
          end

          context "with env['grape.skip_appsignal_error'] = true" do
            before do
              env["grape.skip_appsignal_error"] = true
            end

            it "does not add the error" do
              expect(transaction).to_not receive(:set_error)
            end
          end

          after do
            expect { middleware.call(env) }.to raise_error ExampleException
          end
        end

        context "with route" do
          let(:app) do
            Class.new(::Grape::API) do
              route([:get, :post], "hello") do
                "Hello!"
              end
            end
          end
          let(:env) do
            http_request_env_with_data \
              "api.endpoint" => api_endpoint,
              "REQUEST_METHOD" => "GET",
              :path => ""
          end

          it "sets non-unique route path" do
            expect(transaction).to receive(:set_action).with("GET::GrapeExample::Api#/hello")
            expect(transaction).to receive(:set_metadata).with("path", "/hello")
            expect(transaction).to receive(:set_metadata).with("method", "GET")
          end

          after { middleware.call(env) }
        end

        context "with route_param" do
          let(:app) do
            Class.new(::Grape::API) do
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
            http_request_env_with_data \
              "api.endpoint" => api_endpoint,
              "REQUEST_METHOD" => "GET",
              :path => ""
          end

          it "sets non-unique route_param path" do
            expect(transaction).to receive(:set_action_if_nil)
              .with("GET::GrapeExample::Api#/users/:id/")
            expect(transaction).to receive(:set_metadata).with("path", "/users/:id/")
            expect(transaction).to receive(:set_metadata).with("method", "GET")
          end

          after { middleware.call(env) }
        end

        context "with namespaced path" do
          context "with symbols" do
            let(:app) do
              Class.new(::Grape::API) do
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

            it "sets namespaced path" do
              expect(transaction).to receive(:set_action_if_nil)
                .with("POST::GrapeExample::Api#/v1/beta/ping")
              expect(transaction).to receive(:set_metadata).with("path", "/v1/beta/ping")
              expect(transaction).to receive(:set_metadata).with("method", "POST")
            end
          end

          context "with strings" do
            context "without / prefix" do
              let(:app) do
                Class.new(::Grape::API) do
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

              it "sets namespaced path" do
                expect(transaction).to receive(:set_action_if_nil)
                  .with("POST::GrapeExample::Api#/v1/beta/ping")
                expect(transaction).to receive(:set_metadata).with("path", "/v1/beta/ping")
                expect(transaction).to receive(:set_metadata).with("method", "POST")
              end
            end

            context "with / prefix" do
              let(:app) do
                Class.new(::Grape::API) do
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

              it "sets namespaced path" do
                expect(transaction).to receive(:set_action_if_nil)
                  .with("POST::GrapeExample::Api#/v1/beta/ping")
                expect(transaction).to receive(:set_metadata).with("path", "/v1/beta/ping")
                expect(transaction).to receive(:set_metadata).with("method", "POST")
              end
            end
          end

          after { middleware.call(env) }
        end
      end
    end
  end
end
