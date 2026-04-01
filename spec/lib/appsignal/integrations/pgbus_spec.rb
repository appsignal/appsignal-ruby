require "appsignal/integrations/pgbus"

describe Appsignal::Integrations::PgbusExecutorPlugin do
  let(:queue_name) { "default" }
  let(:enqueued_at) { "2024-01-15T11:00:00Z" }
  let(:job_payload) do
    {
      "job_class" => "TestPgbusJob",
      "job_id" => "abc-123",
      "provider_job_id" => "42",
      "queue_name" => queue_name,
      "arguments" => [1, "hello"],
      "enqueued_at" => enqueued_at
    }
  end
  let(:message) do
    double(
      :message => JSON.generate(job_payload),
      :msg_id => 42,
      :read_ct => 1,
      :headers => {}
    )
  end

  let(:executor_class) do
    Class.new do
      def execute(message, queue_name, source_queue: nil)
        :success
      end
    end.tap { |klass| klass.prepend(described_class) }
  end

  let(:executor) { executor_class.new }

  before { start_agent }
  around { |example| keep_transactions { example.run } }

  describe "#execute" do
    context "without exception" do
      it "creates a background job transaction" do
        expect { executor.execute(message, queue_name) }
          .to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("TestPgbusJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "count" => 1,
          "name" => "perform_job.pgbus",
          "title" => ""
        )
        expect(transaction).to include_params(
          "arguments" => [1, "hello"]
        )
        expect(transaction).to include_tags(
          "queue" => "default",
          "job_class" => "TestPgbusJob",
          "provider_job_id" => "42",
          "active_job_id" => "abc-123",
          "request_id" => "42",
          "attempts" => 1
        )
        expect(transaction).to be_completed
      end

      it "sets queue start from enqueued_at" do
        executor.execute(message, queue_name)

        transaction = last_transaction
        expected_queue_start = (Time.parse(enqueued_at).to_f * 1_000).to_i
        expect(transaction).to have_queue_start(expected_queue_start)
      end

      it "returns the original result" do
        result = executor.execute(message, queue_name)
        expect(result).to eq(:success)
      end

      it "increments pgbus_queue_job_count with processed status" do
        expect(Appsignal).to receive(:increment_counter)
          .with("pgbus_queue_job_count", 1, { :queue => "default", :status => :processed })

        executor.execute(message, queue_name)
      end
    end

    context "with exception" do
      let(:error) { ExampleException.new("job failed") }

      let(:executor_class) do
        err = error
        Class.new do
          define_method(:execute) { |*, **| raise err }
        end.tap { |klass| klass.prepend(described_class) }
      end

      it "reports the error and re-raises" do
        expect { executor.execute(message, queue_name) }
          .to raise_error(ExampleException, "job failed")

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("TestPgbusJob#perform")
        expect(transaction).to have_error("ExampleException", "job failed")
        expect(transaction).to include_tags("queue" => "default")
        expect(transaction).to be_completed
      end

      it "increments pgbus_queue_job_count with failed and processed status" do
        expect(Appsignal).to receive(:increment_counter)
          .with("pgbus_queue_job_count", 1, { :queue => "default", :status => :failed })
        expect(Appsignal).to receive(:increment_counter)
          .with("pgbus_queue_job_count", 1, { :queue => "default", :status => :processed })

        expect { executor.execute(message, queue_name) }
          .to raise_error(ExampleException)
      end
    end

    context "without enqueued_at" do
      let(:enqueued_at) { nil }

      it "does not set queue start" do
        executor.execute(message, queue_name)

        transaction = last_transaction
        expect(transaction).to_not have_queue_start
      end
    end

    context "without provider_job_id" do
      let(:job_payload) do
        {
          "job_class" => "TestPgbusJob",
          "job_id" => "abc-123",
          "queue_name" => queue_name,
          "arguments" => [1],
          "enqueued_at" => enqueued_at
        }
      end

      it "falls back to job_id for request_id tag" do
        executor.execute(message, queue_name)

        expect(last_transaction).to include_tags(
          "request_id" => "abc-123"
        )
      end
    end
  end
end

describe Appsignal::Integrations::PgbusHandlerPlugin do
  let(:event_payload) do
    {
      "event_id" => "evt-456",
      "routing_key" => "orders.created",
      "headers" => { "routing_key" => "orders.created" },
      "payload" => { "order_id" => 1 }
    }
  end
  let(:message) do
    double(
      :message => JSON.generate(event_payload),
      :msg_id => 99,
      :read_ct => 1,
      :headers => {}
    )
  end

  let(:handler_class) do
    Class.new do
      def self.name
        "OrderCreatedHandler"
      end

      def process(message)
        :handled
      end
    end.tap { |klass| klass.prepend(described_class) }
  end

  let(:handler) { handler_class.new }

  before { start_agent }
  around { |example| keep_transactions { example.run } }

  describe "#process" do
    context "without exception" do
      it "creates a background job transaction" do
        expect { handler.process(message) }
          .to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("OrderCreatedHandler#handle")
        expect(transaction).to_not have_error
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "count" => 1,
          "name" => "process_event.pgbus",
          "title" => ""
        )
        expect(transaction).to include_params("order_id" => 1)
        expect(transaction).to include_tags(
          "event_id" => "evt-456",
          "routing_key" => "orders.created",
          "handler" => "OrderCreatedHandler"
        )
        expect(transaction).to be_completed
      end

      it "returns the original result" do
        result = handler.process(message)
        expect(result).to eq(:handled)
      end
    end

    context "with exception" do
      let(:error) { ExampleException.new("handler failed") }

      let(:handler_class) do
        err = error
        Class.new do
          def self.name
            "OrderCreatedHandler"
          end

          define_method(:process) { |*| raise err }
        end.tap { |klass| klass.prepend(described_class) }
      end

      it "reports the error and re-raises" do
        expect { handler.process(message) }
          .to raise_error(ExampleException, "handler failed")

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("OrderCreatedHandler#handle")
        expect(transaction).to have_error("ExampleException", "handler failed")
        expect(transaction).to include_tags(
          "event_id" => "evt-456",
          "routing_key" => "orders.created",
          "handler" => "OrderCreatedHandler"
        )
        expect(transaction).to be_completed
      end
    end

    context "with routing key in top-level field" do
      let(:event_payload) do
        {
          "event_id" => "evt-789",
          "routing_key" => "payments.completed",
          "payload" => { "payment_id" => 5 }
        }
      end

      it "falls back to top-level routing_key" do
        handler.process(message)

        expect(last_transaction).to include_tags(
          "routing_key" => "payments.completed"
        )
      end
    end
  end
end
