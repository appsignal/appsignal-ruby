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
    let(:app) { double(:call => true) }
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

    def make_request(env)
      middleware.call(env)
      last_transaction.complete # Manually close transaction to set sample data
    end

    def make_request_with_error(env, error_class, error_message)
      expect { make_request(env) }.to raise_error(error_class, error_message)
    end

    context "with a request without an error" do
      it "does not report an event" do
        make_request(env)

        expect(last_transaction.to_h).to include(
          "events" => []
        )
      end
    end

    context "with a request that raises an error" do
      let(:app) { lambda { |_env| raise ExampleException, "error message" } }

      it "reports the error on the transaction" do
        make_request_with_error(env, ExampleException, "error message")

        expect(last_transaction.to_h).to include(
          "error" => hash_including(
            "name" => "ExampleException",
            "message" => "error message"
          )
        )
      end
    end

    it "sets the controller action as the action name" do
      make_request(env)

      expect(last_transaction.to_h).to include(
        "namespace" => Appsignal::Transaction::HTTP_REQUEST,
        "action" => "MockController#index"
      )
    end

    it "sets request metadata on the transaction" do
      make_request(env)

      expect(last_transaction.to_h).to include(
        "metadata" => hash_including(
          "method" => "GET",
          "path" => "/blog"
        ),
        "sample_data" => hash_including(
          "tags" => { "request_id" => "request_id123" }
        )
      )
    end

    it "reports Rails filter parameters" do
      make_request(env)

      expect(last_transaction.to_h).to include(
        "sample_data" => hash_including(
          "params" => {
            "controller" => "blog_posts",
            "action" => "show",
            "id" => "1",
            "my_custom_param" => "[FILTERED]",
            "password" => "[FILTERED]"
          }
        )
      )
    end

    context "with an invalid HTTP request method" do
      it "does not store the invalid HTTP request method" do
        make_request(env.merge(:request_method => "FOO", "REQUEST_METHOD" => "FOO"))

        transaction_hash = last_transaction.to_h
        expect(transaction_hash["metadata"]).to_not have_key("method")
        expect(log_contents(log))
          .to contains_log(:error, "Unable to report HTTP request method: '")
      end
    end

    context "with a request path that's not a route" do
      it "doesn't set an action name" do
        make_request(
          env.merge(
            :path => "/unknown-route",
            "action_controller.instance" => nil
          )
        )

        expect(last_transaction.to_h).to include(
          "action" => nil
        )
      end
    end
  end
end
