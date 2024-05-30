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
  before do
    start_agent
    Appsignal.internal_logger = test_logger(log_stream)
  end
  around { |example| keep_transactions { example.run } }

  def on_start
    described_class.new.on_start(request, response)
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
    def on_error(error)
      described_class.new.on_error(request, response, error)
    end

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

    def on_finish
      described_class.new.on_finish(request, response)
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
    end

    it "completes the transaction" do
      on_start
      on_finish

      expect(last_transaction.to_h).to include(
        "action" => "GET /path"
      )
      expect(last_transaction.ext.queue_start).to eq(queue_start_time)
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

    it "logs an error in case of an error" do
      expect(Appsignal::Transaction)
        .to receive(:complete_current!).and_raise(ExampleStandardError, "oh no")

      on_start
      on_finish

      expect(log).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
      )
    end
  end
end
