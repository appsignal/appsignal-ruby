require "appsignal/integrations/shoryuken"

describe Appsignal::Integrations::ShoryukenMiddleware do
  class DemoShoryukenWorker
  end

  let(:time) { "2010-01-01 10:01:00UTC" }
  let(:worker_instance) { DemoShoryukenWorker.new }
  let(:queue) { "some-funky-queue-name" }
  let(:sqs_msg) { double(:message_id => "msg1", :attributes => {}) }
  let(:body) { {} }
  let(:options) { {} }
  before { start_agent(:options => options) }
  around { |example| keep_transactions { example.run } }

  def perform_shoryuken_job(&block)
    block ||= lambda {}
    Timecop.freeze(Time.parse(time)) do
      described_class.new.call(
        worker_instance,
        queue,
        sqs_msg,
        body,
        &block
      )
    end
  end

  context "with a performance call" do
    let(:sent_timestamp) { Time.parse("1976-11-18 0:00:00UTC").to_i * 1000 }
    let(:sqs_msg) do
      double(:message_id => "msg1", :attributes => { "SentTimestamp" => sent_timestamp })
    end

    context "with complex argument" do
      let(:body) { { :foo => "Foo", :bar => "Bar" } }

      it "wraps the job in a transaction with the correct params" do
        expect { perform_shoryuken_job }.to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("DemoShoryukenWorker#perform")
        expect(transaction).to_not have_error
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "count" => 1,
          "name" => "perform_job.shoryuken",
          "title" => ""
        )
        expect(transaction).to include_params("foo" => "Foo", "bar" => "Bar")
        expect(transaction).to include_tags(
          "message_id" => "msg1",
          "queue" => queue,
          "SentTimestamp" => sent_timestamp
        )
        expect(transaction).to have_queue_start(sent_timestamp)
        expect(transaction).to be_completed
      end

      context "with parameter filtering" do
        let(:options) { { :filter_parameters => ["foo"] } }

        it "filters selected arguments" do
          perform_shoryuken_job

          expect(last_transaction).to include_params("foo" => "[FILTERED]", "bar" => "Bar")
        end
      end
    end

    context "with a string as an argument" do
      let(:body) { "foo bar" }

      it "handles string arguments" do
        perform_shoryuken_job

        expect(last_transaction).to include_params("params" => body)
      end
    end

    context "with primitive type as argument" do
      let(:body) { 1 }

      it "handles primitive types as arguments" do
        perform_shoryuken_job

        expect(last_transaction).to include_params("params" => body)
      end
    end
  end

  context "with exception" do
    it "sets the exception on the transaction" do
      expect do
        expect do
          perform_shoryuken_job { raise ExampleException, "error message" }
        end.to raise_error(ExampleException)
      end.to change { created_transactions.length }.by(1)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_action("DemoShoryukenWorker#perform")
      expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
      expect(transaction).to have_error("ExampleException", "error message")
      expect(transaction).to be_completed
    end
  end

  context "with batched jobs" do
    let(:sqs_msg) do
      [
        double(
          :message_id => "msg2",
          :attributes => {
            "SentTimestamp" => (Time.parse("1976-11-18 01:00:00UTC").to_i * 1000).to_s
          }
        ),
        double(
          :message_id => "msg1",
          :attributes => { "SentTimestamp" => sent_timestamp.to_s }
        )
      ]
    end
    let(:body) do
      [
        "foo bar",
        { :id => "123", :foo => "Foo", :bar => "Bar" }
      ]
    end
    let(:sent_timestamp) { Time.parse("1976-11-18 01:00:00UTC").to_i * 1000 }

    it "creates a transaction for the batch" do
      expect do
        perform_shoryuken_job {} # rubocop:disable Lint/EmptyBlock
      end.to change { created_transactions.length }.by(1)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_action("DemoShoryukenWorker#perform")
      expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
      expect(transaction).to_not have_error
      expect(transaction).to include_event(
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "count" => 1,
        "name" => "perform_job.shoryuken",
        "title" => ""
      )
      expect(transaction).to include_params(
        "msg2" => "foo bar",
        "msg1" => { "id" => "123", "foo" => "Foo", "bar" => "Bar" }
      )
      expect(transaction).to include_tags(
        "batch" => true,
        "queue" => "some-funky-queue-name",
        "SentTimestamp" => sent_timestamp.to_s # Earliest/oldest timestamp from messages
      )
      # Queue time based on earliest/oldest timestamp from messages
      expect(transaction).to have_queue_start(sent_timestamp)
    end
  end
end

describe Appsignal::Integrations::ShoryukenClientMiddleware do
  let(:options) { { :message_body => "foo" } }
  before { start_agent }
  around { |example| keep_transactions { example.run } }

  def enqueue(&block)
    block ||= lambda {}
    described_class.new.call(options, &block)
  end

  context "with an active transaction" do
    # Enqueuing through a Shoryuken worker carries the worker class in the
    # `shoryuken_class` message attribute, so the event is titled after it.
    context "enqueued through a worker" do
      let(:options) do
        {
          :message_body => "foo",
          :queue_url => "https://sqs.us-east-1.amazonaws.com/0/my-queue",
          :message_attributes => {
            "shoryuken_class" => { :string_value => "MyShoryukenWorker", :data_type => "String" }
          }
        }
      end

      it "records the enqueue under the transaction, titled after the worker" do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        enqueue

        event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.shoryuken" }
        expect(event).to_not be_nil
        expect(event["title"]).to eq("enqueue MyShoryukenWorker job")
      end
    end

    # A raw `send_message` enqueue has no worker class, so the event falls back
    # to naming the queue it was sent to.
    context "enqueued as a raw message" do
      let(:options) do
        { :message_body => "foo", :queue_url => "https://sqs.us-east-1.amazonaws.com/0/my-queue" }
      end

      it "records the enqueue under the transaction, titled after the queue" do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        enqueue

        event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.shoryuken" }
        expect(event).to_not be_nil
        expect(event["title"]).to eq("enqueue on my-queue")
      end
    end
  end

  context "without an active transaction" do
    it "passes through without recording" do
      expect { |block| enqueue(&block) }.to yield_control
    end
  end

  context "when job enqueue events are suppressed" do
    # As happens under Active Job, which records the enqueue itself.
    it "passes through without recording the enqueue" do
      transaction = http_request_transaction
      set_current_transaction(transaction)

      transaction.suppress_job_enqueue_events { enqueue }

      # The outer integration records the enqueue, so this one doesn't.
      event_names = transaction.to_h["events"].map { |event| event["name"] }
      expect(event_names).to_not include("enqueue.shoryuken")
    end
  end
end
