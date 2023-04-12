if DependencyHelper.rails_present?
  class MockController
  end

  describe Appsignal::Rack::RailsInstrumentation do
    let(:log) { StringIO.new }
    before do
      start_agent
      Appsignal.logger = test_logger(log)
    end

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
    let(:app) { double(:call => true) }
    let(:env) do
      http_request_env_with_data({
        :params => params,
        :with_queue_start => true,
        "action_dispatch.request_id" => "1",
        "action_dispatch.parameter_filter" => [:my_custom_param, :password],
        "action_controller.instance" => double(
          :class => MockController,
          :action_name => "index"
        )
      }.merge(env_extra))
    end
    let(:middleware) { Appsignal::Rack::RailsInstrumentation.new(app, {}) }
    around { |example| keep_transactions { example.run } }

    describe "#call" do
      before do
        allow(middleware).to receive(:raw_payload).and_return({})
      end

      context "when appsignal is active" do
        before { allow(Appsignal).to receive(:active?).and_return(true) }

        it "should call with monitoring" do
          expect(middleware).to receive(:call_with_appsignal_monitoring).with(env)
        end
      end

      context "when appsignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "should not call with monitoring" do
          expect(middleware).to_not receive(:call_with_appsignal_monitoring)
        end

        it "should call the app" do
          expect(app).to receive(:call).with(env)
        end
      end

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      def run
        middleware.call(env)
      end

      it "calls the wrapped app" do
        run
        expect(app).to have_received(:call).with(env)
      end

      it "creates one transaction with metadata" do
        run

        expect(created_transactions.length).to eq(1)
        transaction_hash = last_transaction.to_h
        expect(transaction_hash).to include(
          "namespace" => Appsignal::Transaction::HTTP_REQUEST,
          "action" => "MockController#index",
          "metadata" => hash_including(
            "method" => "GET",
            "path" => "/blog"
          )
        )
        expect(last_transaction.ext.queue_start).to eq(
          fixed_time * 1_000.0
        )
      end

      it "filter parameters in Rails" do
        run

        transaction_hash = last_transaction.to_h
        expect(transaction_hash).to include(
          "sample_data" => hash_including(
            "params" => params.merge(
              "my_custom_param" => "[FILTERED]",
              "password" => "[FILTERED]"
            )
          )
        )
      end

      context "with an invalid HTTP request method" do
        let(:env_extra) { { :request_method => "FOO", "REQUEST_METHOD" => "FOO" } }

        it "does not store the HTTP request method" do
          run

          transaction_hash = last_transaction.to_h
          expect(transaction_hash["metadata"]).to_not have_key("method")
          expect(log_contents(log)).to contains_log(:error,
            "Unable to report HTTP request method: '")
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
    end

    describe "#request_id" do
      subject { middleware.request_id(env) }

      context "with request id present" do
        let(:env) { { "action_dispatch.request_id" => "id" } }

        it "returns the present id" do
          is_expected.to eq "id"
        end
      end

      context "with request id not present" do
        let(:env) { {} }

        it "sets a new id" do
          expect(subject.length).to eq 36
        end
      end
    end
  end
end
