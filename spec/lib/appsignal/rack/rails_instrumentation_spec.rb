if DependencyHelper.rails_present?
  describe Appsignal::Rack::RailsInstrumentation do
    class MockController; end

    let(:log) { StringIO.new }
    before do
      start_agent
      Appsignal.internal_logger = test_logger(log)
    end

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
    let(:env_extra) { {} }
    let(:env) do
      http_request_env_with_data({
        :params => params,
        :with_queue_start => true,
        "action_dispatch.request_id" => "request_id123",
        "action_dispatch.parameter_filter" => [:my_custom_param, :password],
        "action_controller.instance" => double(
          :class => MockController,
          :action_name => "index"
        )
      }.merge(env_extra))
    end
    let(:middleware) { Appsignal::Rack::RailsInstrumentation.new(app, {}) }
    around { |example| keep_transactions { example.run } }
    before do
      env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
    end

    describe "#call" do
      before do
        allow(middleware).to receive(:raw_payload).and_return({})
      end

      context "when appsignal is active" do
        before { allow(Appsignal).to receive(:active?).and_return(true) }

        it "calls with monitoring" do
          expect(middleware).to receive(:call_with_appsignal_monitoring).with(env)
        end
      end

      context "when appsignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not call with monitoring" do
          expect(middleware).to_not receive(:call_with_appsignal_monitoring)
        end

        it "calls the app" do
          expect(app).to receive(:call).with(env)
        end
      end

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      def run
        middleware.call(env)
        last_transaction.complete # Manually close transaction to set sample data
      end

      it "calls the wrapped app" do
        expect { run }.to_not(change { created_transactions.length })
        expect(app).to have_received(:call).with(env)
      end

      it "sets request metadata on the transaction" do
        run

        expect(last_transaction.to_h).to include(
          "namespace" => Appsignal::Transaction::HTTP_REQUEST,
          "action" => "MockController#index",
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
        run

        expect(last_transaction.to_h).to include(
          "sample_data" => hash_including(
            "params" => params.merge(
              "my_custom_param" => "[FILTERED]",
              "password" => "[FILTERED]"
            )
          )
        )
      end

      context "with custom params" do
        let(:app) do
          lambda do |env|
            env[Appsignal::Rack::APPSIGNAL_TRANSACTION].params = { "custom_param" => "yes" }
          end
        end

        it "allows custom params to be set" do
          run

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "params" => {
                "custom_param" => "yes"
              }
            )
          )
        end
      end

      context "with an invalid HTTP request method" do
        let(:env_extra) { { :request_method => "FOO", "REQUEST_METHOD" => "FOO" } }

        it "does not store the HTTP request method" do
          run

          transaction_hash = last_transaction.to_h
          expect(transaction_hash["metadata"]).to_not have_key("method")
          expect(log_contents(log))
            .to contains_log(:error, "Unable to report HTTP request method: '")
        end
      end

      context "with an exception" do
        let(:error) { ExampleException.new("ExampleException message") }
        let(:app) do
          double.tap do |d|
            allow(d).to receive(:call).and_raise(error)
          end
        end

        it "records the exception" do
          expect { run }.to raise_error(error)

          transaction_hash = last_transaction.to_h
          expect(transaction_hash["error"]).to include(
            "name" => "ExampleException",
            "message" => "ExampleException message",
            "backtrace" => kind_of(String)
          )
        end
      end

      context "with a request path that's not a route" do
        let(:env_extra) do
          {
            :path => "/unknown-route",
            "action_controller.instance" => nil
          }
        end

        it "doesn't set an action name" do
          run

          expect(last_transaction.to_h).to include(
            "action" => nil
          )
        end
      end
    end

    describe "#fetch_request_id" do
      subject { middleware.fetch_request_id(env) }

      let(:env) { { "action_dispatch.request_id" => "id" } }

      it "returns the action dispatch id" do
        is_expected.to eq "id"
      end
    end
  end
end
