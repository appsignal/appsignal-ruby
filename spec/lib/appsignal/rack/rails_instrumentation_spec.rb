if DependencyHelper.rails_present?
  describe Appsignal::Rack::RailsInstrumentation do
    class MockController; end

    let(:log) { StringIO.new }
    let(:transaction) do
      Appsignal::Transaction.new(
        "transaction_id",
        Appsignal::Transaction::HTTP_REQUEST,
        Rack::Request.new(env)
      )
    end
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
    around { |example| keep_transactions { example.run } }
    before do
      start_agent
      Appsignal.internal_logger = test_logger(log)
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
      before { make_request }

      it "calls the next middleware in the stack" do
        expect(app).to be_called
      end

      it "does not instrument an event" do
        expect(last_transaction).to_not include_events
      end
    end

    context "with a request that raises an error" do
      let(:app) do
        DummyApp.new { |_env| raise ExampleException, "error message" }
      end
      before do
        make_request_with_error(ExampleException, "error message")
      end

      it "calls the next middleware in the stack" do
        expect(app).to be_called
      end

      it "reports the error on the transaction" do
        expect(last_transaction).to have_error("ExampleException", "error message")
      end
    end

    it "sets the controller action as the action name" do
      make_request

      expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
      expect(last_transaction).to have_action("MockController#index")
    end

    it "sets request metadata on the transaction" do
      make_request

      expect(last_transaction).to include_metadata(
        "method" => "GET",
        "path" => "/blog"
      )
      expect(last_transaction).to include_tags("request_id" => "request_id123")
    end

    it "reports Rails filter parameters" do
      make_request

      expect(last_transaction).to include_params(
        "controller" => "blog_posts",
        "action" => "show",
        "id" => "1",
        "my_custom_param" => "[FILTERED]",
        "password" => "[FILTERED]"
      )
    end

    context "with an invalid HTTP request method" do
      it "does not store the invalid HTTP request method" do
        env[:request_method] = "FOO"
        env["REQUEST_METHOD"] = "FOO"
        make_request

        expect(last_transaction).to_not include_metadata("method" => anything)
        expect(log_contents(log))
          .to contains_log(:error, "Unable to report HTTP request method: '")
      end
    end

    context "with a request path that's not a route" do
      it "doesn't set an action name" do
        env[:path] = "/unknown-route"
        env["action_controller.instance"] = nil
        make_request

        expect(last_transaction).to_not have_action
      end
    end
  end
end
