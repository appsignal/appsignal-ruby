if DependencyHelper.rails_present?
  describe Appsignal::Rack::RailsInstrumentation do
    class MockController; end

    let(:transaction) { new_transaction }
    let(:app) { DummyApp.new }
    let(:params) do
      {
        "controller" => "blog_posts",
        "action" => "show",
        "id" => "1",
        "my_custom_param" => "my custom secret",
        "password" => "super secret"
      }
    end
    let(:env) do
      http_request_env_with_data(
        :params => params,
        :with_queue_start => true,
        "action_dispatch.request_id" => "request_id123",
        "action_dispatch.parameter_filter" => [:my_custom_param, :password],
        "action_controller.instance" => double(
          :class => MockController,
          :action_name => "index"
        )
      )
    end
    let(:middleware) { Appsignal::Rack::RailsInstrumentation.new(app, {}) }

    # The middleware wraps an existing (parent) transaction, so it must be built
    # after the agent starts; register it from the example body, not a `before`.
    def setup_transaction
      env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
    end

    def make_request
      middleware.call(env)
      last_transaction&._sample
    end

    def make_request_with_error(error_class, error_message)
      expect { make_request }.to raise_error(error_class, error_message)
    end

    context "with a request that doesn't raise an error" do
      describe "calls the next middleware in the stack" do
        def perform
          setup_transaction
          make_request
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(app).to be_called
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          # The middleware leaves the parent open; finish it to export the span.
          transaction.complete

          expect(app).to be_called
        end
      end

      describe "does not instrument an event" do
        def perform
          setup_transaction
          make_request
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to_not include_events
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(event_spans).to be_empty
        end
      end
    end

    context "with a request that raises an error" do
      let(:app) do
        DummyApp.new { |_env| raise ExampleException, "error message" }
      end

      describe "calls the next middleware in the stack" do
        def perform
          setup_transaction
          make_request_with_error(ExampleException, "error message")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(app).to be_called
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(app).to be_called
        end
      end

      describe "reports the error on the transaction" do
        def perform
          setup_transaction
          make_request_with_error(ExampleException, "error message")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_error("ExampleException", "error message")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("error message")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end
    end

    describe "sets the controller action as the action name" do
      def perform
        setup_transaction
        make_request
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(last_transaction).to have_action("MockController#index")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.kind).to eq(:server)
        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::HTTP_REQUEST)
        expect(root_span.name).to eq("MockController#index")
        expect(root_span.attributes["appsignal.action_name"]).to eq("MockController#index")
      end
    end

    describe "sets request metadata on the transaction" do
      def perform
        setup_transaction
        make_request
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_metadata(
          "method" => "GET",
          "path" => "/blog"
        )
        expect(last_transaction).to include_tags("request_id" => "request_id123")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        # Metadata and tags are both emitted as `appsignal.tag.*` attributes.
        expect(root_span.attributes["appsignal.tag.method"]).to eq("GET")
        expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
        expect(root_span.attributes["appsignal.tag.request_id"]).to eq("request_id123")
      end
    end

    describe "reports Rails filter parameters" do
      def perform
        setup_transaction
        make_request
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_params(
          "controller" => "blog_posts",
          "action" => "show",
          "id" => "1",
          "my_custom_param" => "[FILTERED]",
          "password" => "[FILTERED]"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        params = JSON.parse(root_span.attributes["appsignal.request.payload"])
        expect(params).to include(
          "controller" => "blog_posts",
          "action" => "show",
          "id" => "1",
          "my_custom_param" => "[FILTERED]",
          "password" => "[FILTERED]"
        )
      end
    end

    context "with an invalid HTTP request method" do
      describe "does not store the invalid HTTP request method" do
        def perform
          setup_transaction
          env[:request_method] = "FOO"
          env["REQUEST_METHOD"] = "FOO"
          capture_logs { make_request }
        end

        it "in agent mode", :agent_mode do
          start_agent
          logs = perform

          expect(last_transaction).to_not include_metadata("method" => anything)
          expect(logs).to contains_log(
            :error,
            "Exception while fetching the HTTP request method: "
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          logs = perform
          transaction.complete

          expect(root_span.attributes.keys).to_not include("appsignal.tag.method")
          expect(logs).to contains_log(
            :error,
            "Exception while fetching the HTTP request method: "
          )
        end
      end
    end

    context "with a request path that's not a route" do
      describe "doesn't set an action name" do
        def perform
          setup_transaction
          env[:path] = "/unknown-route"
          env["action_controller.instance"] = nil
          make_request
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to_not have_action
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.action_name")
        end
      end
    end
  end
end
