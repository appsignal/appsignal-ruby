describe Appsignal::Rack::AbstractMiddleware do
  let(:app) { double(:call => true) }
  let(:request_path) { "/some/path" }
  let(:env) do
    Rack::MockRequest.env_for(
      request_path,
      "REQUEST_METHOD" => "GET",
      :params => { "page" => 2, "query" => "lorem" }
    )
  end
  let(:options) { {} }
  let(:middleware) { Appsignal::Rack::AbstractMiddleware.new(app, options) }

  before(:context) { start_agent }
  around { |example| keep_transactions { example.run } }

  def make_request(env)
    middleware.call(env)
  end

  def make_request_with_error(env, error)
    expect { make_request(env) }.to raise_error(error)
  end

  describe "#call" do
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
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "calls the next middleware in the stack" do
        make_request(env)

        expect(app).to have_received(:call).with(env)
      end

      context "without an exception" do
        it "create a transaction for the request" do
          expect { make_request(env) }.to(change { created_transactions.count }.by(1))

          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::HTTP_REQUEST,
            "action" => nil,
            "error" => nil
          )
        end

        it "reports a process.abstract event" do
          make_request(env)

          expect(last_transaction.to_h).to include(
            "events" => [
              hash_including(
                "body" => "",
                "body_format" => Appsignal::EventFormatter::DEFAULT,
                "count" => 1,
                "name" => "process.abstract",
                "title" => ""
              )
            ]
          )
        end

        it "completes the transaction" do
          make_request(env)
          expect(last_transaction).to be_completed
        end
      end

      context "with an exception" do
        let(:error) { ExampleException.new("error message") }
        before do
          allow(app).to receive(:call).and_raise(error)
          expect { make_request_with_error(env, error) }
            .to(change { created_transactions.count }.by(1))
        end

        it "creates a transaction for the request and records the exception" do
          expect(last_transaction.to_h).to include(
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

      context "without action name metadata" do
        it "reports no action name" do
          make_request(env)

          expect(last_transaction.to_h).to include("action" => nil)
        end
      end

      context "with appsignal.route env" do
        before do
          env["appsignal.route"] = "POST /my-route"
        end

        it "reports the appsignal.route value as the action name" do
          make_request(env)

          expect(last_transaction.to_h).to include("action" => "POST /my-route")
        end
      end

      context "with appsignal.action env" do
        before do
          env["appsignal.action"] = "POST /my-action"
        end

        it "reports the appsignal.route value as the action name" do
          make_request(env)

          expect(last_transaction.to_h).to include("action" => "POST /my-action")
        end
      end

      describe "request metadata" do
        before do
          env.merge!("PATH_INFO" => "/some/path", "REQUEST_METHOD" => "GET")
        end

        it "sets request metadata" do
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
                # and more, but we don't need to test Rack mock defaults
              )
            )
          )
        end

        context "with an invalid HTTP request method" do
          it "stores the invalid HTTP request method" do
            make_request(env.merge("REQUEST_METHOD" => "FOO"))

            expect(last_transaction.to_h["metadata"]).to include("method" => "FOO")
          end
        end

        context "with fetching the request method raises an error" do
          class BrokenRequestMethodRequest < Rack::Request
            def request_method
              raise "uh oh!"
            end
          end

          let(:options) { { :request_class => BrokenRequestMethodRequest } }
          it "does not store the invalid HTTP request method" do
            make_request(env.merge("REQUEST_METHOD" => "FOO"))

            expect(last_transaction.to_h["metadata"]).to_not have_key("method")
          end
        end

        it "sets request parameters" do
          make_request(env)

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "params" => hash_including(
                "page" => "2",
                "query" => "lorem"
              )
            )
          )
        end

        context "when setting custom params" do
          let(:app) do
            lambda { |_env| Appsignal::Transaction.current.set_params("custom" => "param") }
          end

          it "allow custom request parameters to be set" do
            make_request(env)

            expect(last_transaction.to_h).to include(
              "sample_data" => hash_including(
                "params" => hash_including(
                  "custom" => "param"
                )
              )
            )
          end
        end
      end

      context "with queue start header" do
        let(:queue_start_time) { fixed_time * 1_000 }
        before do
          env["HTTP_X_REQUEST_START"] = "t=#{queue_start_time.to_i}" # in milliseconds
        end

        it "sets the queue start" do
          make_request(env)

          expect(last_transaction.ext.queue_start).to eq(queue_start_time)
        end
      end

      class FilteredRequest
        attr_reader :env

        def initialize(env)
          @env = env
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
          env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = http_request_transaction
        end

        it "uses the existing transaction" do
          make_request(env)

          expect { make_request(env) }.to_not(change { created_transactions.count })
        end

        it "doesn't complete the existing transaction" do
          make_request(env)

          expect(env[Appsignal::Rack::APPSIGNAL_TRANSACTION]).to_not be_completed
        end

        context "with custom set action name" do
          it "does not overwrite the action name" do
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION].set_action("My custom action")
            env["appsignal.action"] = "POST /my-action"
            make_request(env)

            expect(last_transaction.to_h).to include("action" => "My custom action")
          end
        end
      end
    end
  end
end
