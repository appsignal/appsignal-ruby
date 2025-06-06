describe Appsignal::Rack::EventHandler do
  let(:queue_start_time) { fixed_time * 1_000 }
  let(:env) do
    {
      "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}", # in milliseconds
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/path",
      "QUERY_STRING" => "query_param1=value1&query_param2=value2",
      "rack.session" => { "session1" => "value1", "session2" => "value2" },
      "rack.input" => StringIO.new("post_param1=value1&post_param2=value2")
    }
  end
  let(:request) { Rack::Request.new(env) }
  let(:response) { nil }
  let(:log_stream) { StringIO.new }
  let(:logs) { log_contents(log_stream) }
  let(:event_handler_instance) { described_class.new }
  let(:appsignal_env) { :default }
  before do
    start_agent(:env => appsignal_env)
    Appsignal.internal_logger = test_logger(log_stream)
  end
  around { |example| keep_transactions { example.run } }

  def on_start
    event_handler_instance.on_start(request, response)
  end

  def on_error(error)
    event_handler_instance.on_error(request, response, error)
  end

  describe "#on_start" do
    it "creates a new transaction" do
      expect { on_start }.to change { created_transactions.length }.by(1)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)

      expect(Appsignal::Transaction.current).to eq(transaction)
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      it "does not create a new transaction" do
        expect { on_start }.to_not(change { created_transactions.length })
      end
    end

    context "when the handler is nested in another EventHandler" do
      it "does not create a new transaction in the nested EventHandler" do
        on_start
        expect { described_class.new.on_start(request, response) }
          .to_not(change { created_transactions.length })
      end
    end

    it "registers transaction on the request environment" do
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to eq(last_transaction)
    end

    it "registers an rack.after_reply callback that completes the transaction" do
      request.env[Appsignal::Rack::RACK_AFTER_REPLY] = []
      expect do
        on_start
      end.to change { request.env[Appsignal::Rack::RACK_AFTER_REPLY].length }.by(1)

      expect(Appsignal::Transaction.current).to eq(last_transaction)

      callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
      callback.call

      expect(Appsignal::Transaction.current).to be_kind_of(Appsignal::Transaction::NilTransaction)

      expect(last_transaction.ext.queue_start).to eq(queue_start_time)
      expect(last_transaction).to include_event(
        "name" => "process_request.rack",
        "title" => "callback: after_reply"
      )
    end

    context "with error inside rack.after_reply handler" do
      before do
        on_start
        # A random spot we can access to raise an error for this test
        expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
          .to receive(:finish_event)
          .and_raise(ExampleStandardError, "oh no")
        callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
        callback.call
      end

      it "completes the transaction" do
        expect(last_transaction).to be_completed
      end

      it "logs an error" do
        expect(logs).to contains_log(
          :error,
          "Error occurred in Appsignal::Rack::EventHandler's after_reply: " \
            "ExampleStandardError: oh no"
        )
      end
    end

    it "logs errors from rack.after_reply callbacks" do
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to receive(:finish_event)
        .and_raise(ExampleStandardError, "oh no")
      callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
      callback.call

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler's after_reply: ExampleStandardError: oh no"
      )
    end

    it "logs an error in case of an error" do
      expect(Appsignal::Transaction)
        .to receive(:create).and_raise(ExampleStandardError, "oh no")

      on_start

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_start: ExampleStandardError: oh no"
      )
    end
  end

  describe "#on_error" do
    it "reports the error" do
      on_start
      on_error(ExampleStandardError.new("the error"))

      expect(last_transaction).to have_error("ExampleStandardError", "the error")
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      it "does not report the transaction" do
        on_start
        on_error(ExampleStandardError.new("the error"))

        expect(last_transaction).to_not have_error
      end
    end

    context "when the handler is nested in another EventHandler" do
      it "does not report the error on the transaction" do
        on_start
        described_class.new.on_error(request, response, ExampleStandardError.new("the error"))

        expect(last_transaction).to_not have_error
      end
    end

    it "logs an error in case of an internal error" do
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to receive(:set_error).and_raise(ExampleStandardError, "oh no")

      on_error(ExampleStandardError.new("the error"))

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_error: ExampleStandardError: oh no"
      )
    end
  end

  describe "#on_finish" do
    let(:response) { Rack::Events::BufferedResponse.new(200, {}, ["body"]) }

    def on_finish(given_request = request, given_response = response)
      event_handler_instance.on_finish(given_request, given_response)
    end

    it "doesn't do anything without a transaction" do
      on_start

      request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = nil

      on_finish

      expect(last_transaction).to_not have_action
      expect(last_transaction).to_not include_events
      expect(last_transaction).to include("sample_data" => {})
      expect(last_transaction).to_not be_completed
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      it "doesn't do anything" do
        request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = http_request_transaction
        on_finish

        expect(last_transaction).to_not have_action
        expect(last_transaction).to_not include_events
        expect(last_transaction).to include("sample_data" => {})
        expect(last_transaction).to_not be_completed
      end
    end

    it "sets params on the transaction" do
      on_start
      on_finish

      expect(last_transaction).to include_params(
        "query_param1" => "value1",
        "query_param2" => "value2",
        "post_param1" => "value1",
        "post_param2" => "value2"
      )
    end

    it "sets headers on the transaction" do
      on_start
      on_finish

      expect(last_transaction).to include_environment(
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/path"
      )
    end

    it "sets session data on the transaction" do
      on_start
      on_finish

      expect(last_transaction).to include_session_data(
        "session1" => "value1",
        "session2" => "value2"
      )
    end

    it "sets the queue start time on the transaction" do
      on_start
      on_finish

      expect(last_transaction).to have_queue_start(queue_start_time)
    end

    it "completes the transaction" do
      on_start
      on_finish

      expect(last_transaction).to_not have_action
      expect(last_transaction).to be_completed
    end

    context "without a response" do
      it "sets params on the transaction" do
        on_start
        on_finish

        expect(last_transaction).to include_params(
          "query_param1" => "value1",
          "query_param2" => "value2",
          "post_param1" => "value1",
          "post_param2" => "value2"
        )
      end

      it "sets headers on the transaction" do
        on_start
        on_finish

        expect(last_transaction).to include_environment(
          "REQUEST_METHOD" => "POST",
          "PATH_INFO" => "/path"
        )
      end

      it "sets session data on the transaction" do
        on_start
        on_finish

        expect(last_transaction).to include_session_data(
          "session1" => "value1",
          "session2" => "value2"
        )
      end

      it "sets the queue start time on the transaction" do
        on_start
        on_finish

        expect(last_transaction).to have_queue_start(queue_start_time)
      end

      it "completes the transaction" do
        on_start
        on_finish(request, nil)

        # The action is not set on purpose, as we can't set a normalized route
        # It requires the app to set an action name
        expect(last_transaction).to_not have_action
        expect(last_transaction).to be_completed
      end

      it "does not set a response_status tag" do
        on_start
        on_finish(request, nil)

        expect(last_transaction).to_not include_tags("response_status" => anything)
      end

      it "does not report a response_status counter metric" do
        expect(Appsignal).to_not receive(:increment_counter)
          .with(:response_status, anything, anything)

        on_start
        on_finish(request, nil)
      end

      context "with an error previously recorded by on_error" do
        it "sets response status 500 as a tag" do
          on_start
          on_error(ExampleStandardError.new("the error"))
          on_finish(request, nil)

          expect(last_transaction).to include_tags("response_status" => 500)
        end

        it "increments the response status counter for response status 500" do
          expect(Appsignal).to receive(:increment_counter)
            .with(:response_status, 1, :status => 500, :namespace => :web)

          on_start
          on_error(ExampleStandardError.new("the error"))
          on_finish(request, nil)
        end
      end
    end

    context "with error inside on_finish handler" do
      before do
        on_start
        # A random spot we can access to raise an error for this test
        expect(Appsignal).to receive(:increment_counter).and_raise(ExampleStandardError, "oh no")
        on_finish
      end

      it "completes the transaction" do
        expect(last_transaction).to be_completed
      end

      it "logs an error" do
        expect(logs).to contains_log(
          :error,
          "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
        )
      end
    end

    context "when the handler is nested in another EventHandler" do
      it "does not complete the transaction" do
        on_start
        described_class.new.on_finish(request, response)

        expect(last_transaction).to_not have_action
        expect(last_transaction).to_not include_metadata
        expect(last_transaction).to_not include_events
        expect(last_transaction.to_h).to include("sample_data" => {})
        expect(last_transaction).to_not be_completed
      end
    end

    it "doesn't set the action name if already set" do
      on_start
      last_transaction.set_action("My action")
      on_finish

      expect(last_transaction).to have_action("My action")
    end

    it "finishes the process_request.rack event" do
      on_start
      on_finish

      expect(last_transaction).to include_event(
        "name" => "process_request.rack",
        "title" => "callback: on_finish"
      )
    end

    context "with response" do
      it "sets the response status as a tag" do
        on_start
        on_finish

        expect(last_transaction).to include_tags("response_status" => 200)
      end

      it "increments the response status counter for response status" do
        expect(Appsignal).to receive(:increment_counter)
          .with(:response_status, 1, :status => 200, :namespace => :web)

        on_start
        on_finish
      end

      context "with an error previously recorded by on_error" do
        it "sets response status from the response as a tag" do
          on_start
          on_error(ExampleStandardError.new("the error"))
          on_finish

          expect(last_transaction).to include_tags("response_status" => 200)
        end

        it "increments the response status counter based on the response" do
          expect(Appsignal).to receive(:increment_counter)
            .with(:response_status, 1, :status => 200, :namespace => :web)

          on_start
          on_error(ExampleStandardError.new("the error"))
          on_finish
        end
      end
    end

    it "logs an error in case of an error" do
      # A random spot we can access to raise an error for this test
      expect(Appsignal).to receive(:increment_counter).and_raise(ExampleStandardError, "oh no")

      on_start
      on_finish

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
      )
    end
  end
end
