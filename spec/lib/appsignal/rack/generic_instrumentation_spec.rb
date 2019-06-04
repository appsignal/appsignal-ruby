describe Appsignal::Rack::GenericInstrumentation do
  let(:app) { double(:call => true) }
  let(:env) { { "path" => "/", "REQUEST_METHOD" => "GET" } }
  let(:options) { {} }
  let(:middleware) { Appsignal::Rack::GenericInstrumentation.new(app, options) }
  before(:context) { start_agent }

  describe "#call" do
    let(:app) { lambda { |_args| :app_result } }

    context "when AppSignal is not active" do
      before do
        expect(Appsignal).to receive(:active?).and_return(false)
      end

      it "calls the app and returns the result" do
        expect(app).to receive(:call).with(env).and_call_original
        expect(middleware.call(env)).to eql(:app_result)
      end

      it "does not create an AppSignal transaction" do
        expect(Appsignal::Transaction).to_not receive(:create)
        middleware.call(env)
      end
    end

    context "when AppSignal is active" do
      let(:transaction) do
        Appsignal::Transaction.new(
          "1",
          Appsignal::Transaction::HTTP_REQUEST,
          Rack::Request.new(env)
        )
      end
      before do
        allow(Appsignal::Transaction).to receive(:new)
          .with(kind_of(String), Appsignal::Transaction::HTTP_REQUEST, anything, {}) { |_id, _type, rack_env|
            expect(rack_env.env).to include(env)
          }.and_return(transaction)
        allow(transaction).to receive(:complete)
      end

      it "calls the app and returns the result" do
        expect(app).to receive(:call).with(env).and_call_original
        expect(middleware.call(env)).to eql(:app_result)
      end

      it "creates a transaction with the request metadata" do
        middleware.call(env)
        expect(transaction).to match_transaction(
          "id" => "1",
          "events" => [
            be_transaction_event(
              "name" => "process_action.generic",
              "title" => "",
              "body" => "",
              "body_format" => Appsignal::EventFormatter::DEFAULT
            )
          ],
          "metadata" => { "method" => "GET", "path" => "" },
          "namespace" => Appsignal::Transaction::HTTP_REQUEST
        )
      end

      context "with a queue start header" do
        before do
          env.merge!("HTTP_X_QUEUE_START" => "946_681_200_001")
        end

        it "sets the queue start time" do
          expect(transaction).to receive(:set_http_or_background_queue_start).and_call_original
          middleware.call(env)
          expect(transaction).to match_transaction(
            "id" => "1",
            "events" => [
              be_transaction_event(
                "name" => "process_action.generic",
                "title" => "",
                "body" => "",
                "body_format" => Appsignal::EventFormatter::DEFAULT
              )
            ],
            "metadata" => { "method" => "GET", "path" => "" },
            "namespace" => Appsignal::Transaction::HTTP_REQUEST
          )
        end
      end

      context "without custom appsignal.route env" do
        it "sets 'unknown' as the action name" do
          middleware.call(env)
          expect(transaction).to match_transaction(
            "action" => "unknown"
          )
        end
      end

      context "with custom appsignal.route env" do
        before { env.merge!("appsignal.route" => "action_name") }

        it "uses appsignal.route value for action name" do
          middleware.call(env)
          expect(transaction).to match_transaction(
            "action" => "action_name"
          )
        end
      end

      context "when an error occurs" do
        let(:error) { ExampleException }
        let(:app) { lambda { |_args| raise error, "error message" } }

        it "uses appsignal.route value for action name" do
          expect { middleware.call(env) }.to raise_error(error)
          expect(transaction).to match_transaction(
            "error" => be_transaction_error(
              "name" => "ExampleException",
              "message" => "error message"
            )
          )
        end
      end
    end
  end
end
