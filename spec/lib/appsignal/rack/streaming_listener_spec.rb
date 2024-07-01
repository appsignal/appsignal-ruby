require "appsignal/rack/streaming_listener"

describe Appsignal::Rack::StreamingListener do
  let(:env) do
    {
      "rack.input" => StringIO.new,
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/homepage",
      "QUERY_STRING" => "param=something"
    }
  end
  let(:app) { DummyApp.new }
  let(:listener) { Appsignal::Rack::StreamingListener.new(app, {}) }
  before(:context) { start_agent }
  around { |example| keep_transactions { example.run } }

  describe "#call" do
    context "when Appsignal is not active" do
      before { allow(Appsignal).to receive(:active?).and_return(false) }

      it "does not create a transaction" do
        expect do
          listener.call(env)
        end.to_not(change { created_transactions.count })
      end

      it "calls the app" do
        listener.call(env)

        expect(app).to be_called
      end
    end

    context "when Appsignal is active" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      let(:wrapper) { Appsignal::StreamWrapper.new("body", transaction) }
      let(:raw_payload) { { :foo => :bar } }
      before { allow(listener).to receive(:raw_payload).and_return(raw_payload) }

      it "creates a transaction" do
        expect do
          listener.call(env)
        end.to(change { created_transactions.count }.by(1))
      end

      it "instruments the call" do
        listener.call(env)

        expect(last_transaction).to include_event("name" => "process_action.rack")
      end

      it "set `appsignal.action` to the action name" do
        env["appsignal.action"] = "Action"

        listener.call(env)

        expect(last_transaction).to have_action("Action")
      end

      it "adds the path, method and queue start to the transaction" do
        listener.call(env)

        expect(last_transaction).to include_metadata(
          "path" => "/homepage",
          "method" => "GET"
        )
        expect(last_transaction).to have_queue_start
      end

      context "with an exception in the instrumentation call" do
        let(:error) { ExampleException.new("error message") }
        let(:app) { DummyApp.new { raise error } }

        it "adds the exception to the transaction" do
          expect do
            listener.call(env)
          end.to raise_error(error)

          expect(last_transaction).to have_error("ExampleException", "error message")
        end
      end

      it "wraps the body in a wrapper" do
        _, _, body = listener.call(env)

        expect(body).to be_a(Appsignal::StreamWrapper)
      end
    end
  end
end

describe Appsignal::StreamWrapper do
  let(:stream) { double }
  let(:transaction) { http_request_transaction }
  let(:wrapper) { Appsignal::StreamWrapper.new(stream, transaction) }
  before do
    start_agent
    set_current_transaction(transaction)
  end
  around { |example| keep_transactions { example.run } }

  describe "#each" do
    it "calls the original stream" do
      expect(stream).to receive(:each)

      wrapper.each
    end

    context "when #each raises an error" do
      let(:error) { ExampleException.new("error message") }

      it "records the exception" do
        allow(stream).to receive(:each).and_raise(error)

        expect { wrapper.send(:each) }.to raise_error(error)

        expect(transaction).to have_error("ExampleException", "error message")
      end
    end
  end

  describe "#close" do
    it "closes the original stream and completes the transaction" do
      expect(stream).to receive(:close)

      wrapper.close

      expect(current_transaction?).to be_falsy
      expect(transaction).to be_completed
    end

    context "when #close raises an error" do
      let(:error) { ExampleException.new("error message") }

      it "records the exception and completes the transaction" do
        allow(stream).to receive(:close).and_raise(error)

        expect { wrapper.send(:close) }.to raise_error(error)

        expect(transaction).to have_error("ExampleException", "error message")
        expect(transaction).to be_completed
      end
    end
  end
end
