describe Appsignal::Rack::EventHandler do
  let(:queue_start_time) { fixed_time * 1_000 }
  let(:env) do
    {
      "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}", # in milliseconds
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/path"
    }
  end
  let(:request) { Rack::Request.new(env) }
  let(:response) { nil }
  let(:log_stream) { StringIO.new }
  let(:log) { log_contents(log_stream) }
  let(:event_handler_instance) { described_class.new }
  before do
    start_agent
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
      expect(transaction.to_h).to include(
        "id" => kind_of(String),
        "namespace" => Appsignal::Transaction::HTTP_REQUEST
      )

      expect(Appsignal::Transaction.current).to eq(last_transaction)
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
        expect(log).to contains_log(
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

      expect(log).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler's after_reply: ExampleStandardError: oh no"
      )
    end

    it "logs an error in case of an error" do
      expect(Appsignal::Transaction)
        .to receive(:create).and_raise(ExampleStandardError, "oh no")

      on_start

      expect(log).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_start: ExampleStandardError: oh no"
      )
    end
  end

  describe "#on_error" do
    it "reports the error" do
      on_start
      on_error(ExampleStandardError.new("the error"))

      expect(last_transaction.to_h).to include(
        "error" => {
          "name" => "ExampleStandardError",
          "message" => "the error",
          "backtrace" => kind_of(String)
        }
      )
    end

    context "when the handler is nested in another EventHandler" do
      it "does not report the error on the transaction" do
        on_start
        described_class.new.on_error(request, response, ExampleStandardError.new("the error"))

        expect(last_transaction.to_h).to include("error" => nil)
      end
    end

    it "logs an error in case of an internal error" do
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to receive(:set_error).and_raise(ExampleStandardError, "oh no")

      on_error(ExampleStandardError.new("the error"))

      expect(log).to contains_log(
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

      expect(last_transaction.to_h).to include(
        "action" => nil,
        "sample_data" => {},
        "events" => []
      )
      expect(last_transaction).to_not be_completed
    end

    it "completes the transaction" do
      on_start
      on_finish

      expect(last_transaction.to_h).to include(
        # The action is not set on purpose, as we can't set a normalized route
        # It requires the app to set an action name
        "action" => nil,
        "sample_data" => hash_including(
          "environment" => {
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => "/path"
          }
        )
      )
      expect(last_transaction.ext.queue_start).to eq(queue_start_time)
      expect(last_transaction).to be_completed
    end

    context "without a response" do
      it "completes the transaction" do
        on_start
        on_finish(request, nil)

        expect(last_transaction.to_h).to include(
          # The action is not set on purpose, as we can't set a normalized route
          # It requires the app to set an action name
          "action" => nil,
          "sample_data" => hash_including(
            "environment" => {
              "REQUEST_METHOD" => "GET",
              "PATH_INFO" => "/path"
            }
          )
        )
        expect(last_transaction.ext.queue_start).to eq(queue_start_time)
        expect(last_transaction).to be_completed
      end

      it "does not set a response_status tag" do
        on_start
        on_finish(request, nil)

        expect(last_transaction.to_h.dig("sample_data", "tags")).to_not have_key("response_status")
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

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "tags" => { "response_status" => 500 }
            )
          )
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
        expect(log).to contains_log(:error,
          "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no")
      end
    end

    context "when the handler is nested in another EventHandler" do
      it "does not complete the transaction" do
        on_start
        described_class.new.on_finish(request, response)

        expect(last_transaction.to_h).to include(
          "action" => nil,
          "metadata" => {},
          "sample_data" => {},
          "events" => []
        )
        expect(last_transaction).to_not be_completed
      end
    end

    it "doesn't set the action name if already set" do
      on_start
      last_transaction.set_action("My action")
      on_finish

      expect(last_transaction.to_h).to include(
        "action" => "My action"
      )
    end

    it "finishes the process_request.rack event" do
      on_start
      on_finish

      expect(last_transaction.to_h).to include(
        "events" => [
          hash_including(
            "name" => "process_request.rack",
            "title" => "",
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT
          )
        ]
      )
    end

    context "with response" do
      it "sets the response status as a tag" do
        on_start
        on_finish

        expect(last_transaction.to_h).to include(
          "sample_data" => hash_including(
            "tags" => { "response_status" => 200 }
          )
        )
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

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "tags" => { "response_status" => 200 }
            )
          )
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

      expect(log).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
      )
    end
  end
end
