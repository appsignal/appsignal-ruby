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

  # Pass the example's options through to the mode contexts' `start_agent`. In
  # collector mode `start_collector_agent` merges these on top of the
  # `collector_endpoint`, so options like `:filter_parameters` apply in both
  # modes.
  let(:start_agent_args) { { :options => options } }

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
    let(:sent_timestamp) { Time.parse("2024-11-18 0:00:00UTC").to_i * 1000 }
    let(:sqs_msg) do
      double(:message_id => "msg1", :attributes => { "SentTimestamp" => sent_timestamp })
    end

    context "with complex argument" do
      let(:body) { { :foo => "Foo", :bar => "Bar" } }

      describe "wraps the job in a transaction" do
        def perform
          perform_shoryuken_job
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          expect { perform }.to change { created_transactions.length }.by(1)

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

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect { perform }.to change { created_transactions.length }.by(1)

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["appsignal.namespace"])
            .to eq(Appsignal::Transaction::BACKGROUND_JOB)
          expect(root_span.name).to eq("DemoShoryukenWorker#perform")
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("DemoShoryukenWorker#perform")
          expect(exception_events).to be_empty
          span = event_spans.find { |s| s.name == "perform_job.shoryuken" }
          expect(span).not_to be_nil
          expect(span.parent_span_id).to eq(root_span.span_id)
          expect(span.attributes).not_to have_key("appsignal.body")
          expect(span.attributes["appsignal.category"]).to eq("perform_job.shoryuken")
          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
            .to eq("foo" => "Foo", "bar" => "Bar")
          expect(root_span.attributes["appsignal.tag.message_id"]).to eq("msg1")
          expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
          expect(root_span.attributes["appsignal.tag.SentTimestamp"]).to eq(sent_timestamp)
          queue_event = Array(root_span.events).find { |e| e.name == "appsignal.queue_start" }
          expect(queue_event.attributes["appsignal.queue_start"]).to eq(sent_timestamp)
          expect(last_transaction).to be_completed
        end
      end

      context "with parameter filtering" do
        let(:options) { { :filter_parameters => ["foo"] } }

        describe "filters selected arguments" do
          def perform
            perform_shoryuken_job
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to include_params("foo" => "[FILTERED]", "bar" => "Bar")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq("foo" => "[FILTERED]", "bar" => "Bar")
          end
        end
      end
    end

    context "with a string as an argument" do
      let(:body) { "foo bar" }

      describe "handles string arguments" do
        def perform
          perform_shoryuken_job
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(last_transaction).to include_params("params" => body)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
            .to eq("params" => body)
        end
      end
    end

    context "with primitive type as argument" do
      let(:body) { 1 }

      describe "handles primitive types as arguments" do
        def perform
          perform_shoryuken_job
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(last_transaction).to include_params("params" => body)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
            .to eq("params" => body)
        end
      end
    end
  end

  context "with exception" do
    describe "sets the exception on the transaction" do
      def perform
        perform_shoryuken_job { raise ExampleException, "error message" }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect do
          expect { perform }.to raise_error(ExampleException)
        end.to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_action("DemoShoryukenWorker#perform")
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_error("ExampleException", "error message")
        expect(transaction).to be_completed
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect do
          expect { perform }.to raise_error(ExampleException)
        end.to change { created_transactions.length }.by(1)

        expect(root_span.kind).to eq(:consumer)
        expect(root_span.attributes["appsignal.action_name"])
          .to eq("DemoShoryukenWorker#perform")
        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::BACKGROUND_JOB)

        error_event = exception_events
          .find { |e| e.attributes["exception.type"] == "ExampleException" }
        expect(error_event).not_to be_nil
        expect(error_event.attributes["exception.message"]).to eq("error message")
        expect(error_event.attributes["exception.stacktrace"]).to be_a(String)
        expect(error_event.attributes["appsignal.alert_this_error"]).to eq(true)
        expect(last_transaction).to be_completed
      end
    end
  end

  context "with batched jobs" do
    let(:sqs_msg) do
      [
        double(
          :message_id => "msg2",
          :attributes => {
            "SentTimestamp" => (Time.parse("2024-11-18 01:00:00UTC").to_i * 1000).to_s
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
    let(:sent_timestamp) { Time.parse("2024-11-18 01:00:00UTC").to_i * 1000 }

    describe "creates a transaction for the batch" do
      def perform
        perform_shoryuken_job {} # rubocop:disable Lint/EmptyBlock
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect { perform }.to change { created_transactions.length }.by(1)

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

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect { perform }.to change { created_transactions.length }.by(1)

        expect(root_span.kind).to eq(:consumer)
        expect(root_span.name).to eq("DemoShoryukenWorker#perform")
        expect(root_span.attributes["appsignal.action_name"])
          .to eq("DemoShoryukenWorker#perform")
        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::BACKGROUND_JOB)
        expect(exception_events).to be_empty
        span = event_spans.find { |s| s.name == "perform_job.shoryuken" }
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes).not_to have_key("appsignal.body")
        expect(span.attributes["appsignal.category"]).to eq("perform_job.shoryuken")
        expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
          .to eq(
            "msg2" => "foo bar",
            "msg1" => { "id" => "123", "foo" => "Foo", "bar" => "Bar" }
          )
        expect(root_span.attributes["appsignal.tag.batch"]).to eq(true)
        expect(root_span.attributes["appsignal.tag.queue"]).to eq("some-funky-queue-name")
        # Earliest/oldest timestamp from messages
        expect(root_span.attributes["appsignal.tag.SentTimestamp"])
          .to eq(sent_timestamp.to_s)
        queue_event = Array(root_span.events).find { |e| e.name == "appsignal.queue_start" }
        expect(queue_event.attributes["appsignal.queue_start"]).to eq(sent_timestamp)
      end
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
