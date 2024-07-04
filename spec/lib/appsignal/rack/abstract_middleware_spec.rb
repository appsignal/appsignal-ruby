describe Appsignal::Rack::AbstractMiddleware do
  let(:app) { DummyApp.new }
  let(:request_path) { "/some/path" }
  let(:env) do
    Rack::MockRequest.env_for(
      request_path,
      "REQUEST_METHOD" => "GET",
      :params => { "page" => 2, "query" => "lorem" }
    )
  end
  let(:options) { {} }
  let(:middleware) { described_class.new(app, options) }

  before(:context) { start_agent }
  around { |example| keep_transactions { example.run } }

  def make_request
    middleware.call(env)
  end

  def make_request_with_error(error_class, error_message)
    expect { make_request }.to raise_error(error_class, error_message)
  end

  describe "#call" do
    context "when not active" do
      before { allow(Appsignal).to receive(:active?).and_return(false) }

      it "does not instrument the request" do
        expect { make_request }.to_not(change { created_transactions.count })
      end

      it "calls the next middleware in the stack" do
        make_request
        expect(app).to be_called
      end
    end

    context "when appsignal is active" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "creates a transaction for the request" do
        expect { make_request }.to(change { created_transactions.count }.by(1))

        expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
      end

      context "without an error" do
        before { make_request }

        it "calls the next middleware in the stack" do
          expect(app).to be_called
        end

        it "does not record an error" do
          expect(last_transaction).to_not have_error
        end

        context "without :instrument_span_name option set" do
          let(:options) { {} }

          it "does not record an instrumentation event" do
            expect(last_transaction).to_not include_event
          end
        end

        context "with :instrument_span_name option set" do
          let(:options) { { :instrument_span_name => "span_name.category" } }

          it "records an instrumentation event" do
            expect(last_transaction).to include_event(:name => "span_name.category")
          end
        end

        it "completes the transaction" do
          expect(last_transaction).to be_completed
          expect(Appsignal::Transaction.current)
            .to be_kind_of(Appsignal::Transaction::NilTransaction)
        end

        context "when instrument_span_name option is nil" do
          let(:options) { { :instrument_span_name => nil } }

          it "does not record an instrumentation event" do
            expect(last_transaction).to_not include_events
          end
        end
      end

      context "with an error" do
        let(:error) { ExampleException.new("error message") }
        let(:app) { lambda { |_env| raise ExampleException, "error message" } }

        it "create a transaction for the request" do
          expect { make_request_with_error(ExampleException, "error message") }
            .to(change { created_transactions.count }.by(1))

          expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end

        describe "error" do
          before do
            make_request_with_error(ExampleException, "error message")
          end

          it "records the error" do
            expect(last_transaction).to have_error("ExampleException", "error message")
          end

          it "completes the transaction" do
            expect(last_transaction).to be_completed
            expect(Appsignal::Transaction.current)
              .to be_kind_of(Appsignal::Transaction::NilTransaction)
          end

          context "with :report_errors set to false" do
            let(:app) { lambda { |_env| raise ExampleException, "error message" } }
            let(:options) { { :report_errors => false } }

            it "does not record the exception on the transaction" do
              expect(last_transaction).to_not have_error
            end
          end

          context "with :report_errors set to true" do
            let(:app) { lambda { |_env| raise ExampleException, "error message" } }
            let(:options) { { :report_errors => true } }

            it "records the exception on the transaction" do
              expect(last_transaction).to have_error("ExampleException", "error message")
            end
          end

          context "with :report_errors set to a lambda that returns false" do
            let(:app) { lambda { |_env| raise ExampleException, "error message" } }
            let(:options) { { :report_errors => lambda { |_env| false } } }

            it "does not record the exception on the transaction" do
              expect(last_transaction).to_not have_error
            end
          end

          context "with :report_errors set to a lambda that returns true" do
            let(:app) { lambda { |_env| raise ExampleException, "error message" } }
            let(:options) { { :report_errors => lambda { |_env| true } } }

            it "records the exception on the transaction" do
              expect(last_transaction).to have_error("ExampleException", "error message")
            end
          end
        end
      end

      context "without action name metadata" do
        it "reports no action name" do
          make_request

          expect(last_transaction).to_not have_action
        end
      end

      context "with appsignal.route env" do
        before { env["appsignal.route"] = "POST /my-route" }

        it "reports the appsignal.route value as the action name" do
          make_request

          expect(last_transaction).to have_action("POST /my-route")
        end

        it "prints a deprecation warning" do
          err_stream = std_stream
          capture_std_streams(std_stream, err_stream) do
            make_request
          end

          expect(err_stream.read).to include(
            "Setting the action name with the request env 'appsignal.route' is deprecated."
          )
        end

        it "logs a deprecation warning" do
          logs = capture_logs { make_request }
          expect(logs).to contains_log(
            :warn,
            "Setting the action name with the request env 'appsignal.route' is deprecated."
          )
        end
      end

      context "with appsignal.action env" do
        before { env["appsignal.action"] = "POST /my-action" }

        it "reports the appsignal.action value as the action name" do
          make_request

          expect(last_transaction).to have_action("POST /my-action")
        end

        it "prints a deprecation warning" do
          err_stream = std_stream
          capture_std_streams(std_stream, err_stream) do
            make_request
          end

          expect(err_stream.read).to include(
            "Setting the action name with the request env 'appsignal.action' is deprecated."
          )
        end

        it "logs a deprecation warning" do
          logs = capture_logs { make_request }
          expect(logs).to contains_log(
            :warn,
            "Setting the action name with the request env 'appsignal.action' is deprecated."
          )
        end
      end

      describe "request metadata" do
        it "sets request metadata" do
          env.merge!("PATH_INFO" => "/some/path", "REQUEST_METHOD" => "GET")
          make_request

          expect(last_transaction).to include_metadata(
            "method" => "GET",
            "path" => "/some/path"
          )
          expect(last_transaction).to include_environment(
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => "/some/path"
            # and more, but we don't need to test Rack mock defaults
          )
        end

        context "with an invalid HTTP request method" do
          it "stores the invalid HTTP request method" do
            env["REQUEST_METHOD"] = "FOO"
            make_request

            expect(last_transaction).to include_metadata("method" => "FOO")
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
            env["REQUEST_METHOD"] = "FOO"
            make_request

            expect(last_transaction).to_not include_metadata("method" => anything)
          end
        end

        it "sets request parameters" do
          make_request

          expect(last_transaction).to include_params(
            "page" => "2",
            "query" => "lorem"
          )
        end

        context "when setting custom params" do
          let(:app) do
            DummyApp.new do |_env|
              Appsignal::Transaction.current.set_params("custom" => "param")
            end
          end

          it "allow custom request parameters to be set" do
            make_request

            expect(last_transaction).to include_params("custom" => "param")
          end
        end
      end

      context "with queue start header" do
        let(:queue_start_time) { fixed_time * 1_000 }

        it "sets the queue start" do
          env["HTTP_X_REQUEST_START"] = "t=#{queue_start_time.to_i}" # in milliseconds
          make_request

          expect(last_transaction).to have_queue_start(queue_start_time)
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
          make_request

          expect(last_transaction).to include_params("abc" => "123")
        end
      end

      context "with parent instrumentation" do
        before do
          env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = http_request_transaction
        end

        it "uses the existing transaction" do
          make_request

          expect { make_request }.to_not(change { created_transactions.count })
        end

        context "with error" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }

          it "doesn't record the error on the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to_not have_error
          end
        end

        it "doesn't complete the existing transaction" do
          make_request

          expect(env[Appsignal::Rack::APPSIGNAL_TRANSACTION]).to_not be_completed
        end

        context "with custom set action name" do
          it "does not overwrite the action name" do
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION].set_action("My custom action")
            env["appsignal.action"] = "POST /my-action"
            make_request

            expect(last_transaction).to have_action("My custom action")
          end
        end

        context "with :report_errors set to false" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => false } }

          it "does not record the error on the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to_not have_error
          end
        end

        context "with :report_errors set to true" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => true } }

          it "records the error on the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to have_error("ExampleException", "error message")
          end
        end

        context "with :report_errors set to a lambda that returns false" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => lambda { |_env| false } } }

          it "does not record the exception on the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to_not have_error
          end
        end

        context "with :report_errors set to a lambda that returns true" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => lambda { |_env| true } } }

          it "records the error on the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to have_error("ExampleException", "error message")
          end
        end
      end
    end
  end
end
