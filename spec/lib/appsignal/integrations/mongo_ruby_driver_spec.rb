require "appsignal/integrations/mongo_ruby_driver"

describe Appsignal::Hooks::MongoMonitorSubscriber do
  if DependencyHelper.mongo_present?
    let(:subscriber) { Appsignal::Hooks::MongoMonitorSubscriber.new }
    let(:address) { Mongo::Address.new("127.0.0.1:27017") }

    # Build real `Mongo::Monitoring::Event` objects so the subscriber is
    # exercised against the driver's actual event API rather than doubles. The
    # constructors don't open a connection, so no MongoDB server is needed.
    def command_started_event(
      request_id: 1, command_name: "find",
      command: { "foo" => "bar" }, database_name: "test"
    )
      Mongo::Monitoring::Event::CommandStarted.new(
        command_name, database_name, address, request_id, 1, command
      )
    end

    def command_succeeded_event(
      started_event, request_id: 1, command_name: "find",
      database_name: "test", duration: 0.9919
    )
      Mongo::Monitoring::Event::CommandSucceeded.new(
        command_name, database_name, address, request_id, 1, {}, duration,
        :started_event => started_event
      )
    end

    def command_failed_event(
      started_event, request_id: 1, command_name: "find",
      database_name: "test", duration: 0.9919
    )
      Mongo::Monitoring::Event::CommandFailed.new(
        command_name, database_name, address, request_id, 1, "message", {}, duration,
        :started_event => started_event
      )
    end

    # `started` sanitizes the command and stores it on the transaction, keyed by
    # request id, for the matching `succeeded`/`failed` to pick up.
    it "stores the sanitized command on the transaction" do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)

      subscriber.started(command_started_event(:request_id => 1))

      expect(transaction.store("mongo_driver")).to eq(1 => { "foo" => "?" })
    end

    describe "instrumenting a successful query" do
      let(:started_event) { command_started_event(:request_id => 2) }
      let(:succeeded_event) { command_succeeded_event(started_event, :request_id => 2) }

      def perform
        subscriber.started(started_event)
        subscriber.succeeded(succeeded_event)
      end

      it "records the query as an event and emits a duration metric" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

      it "should store command on the transaction" do
        subscriber.started(event)

        expect(transaction.store("mongo_driver")).to eq(1 => { "foo" => "?" })
      end

      it "should start an event in the extension" do
        expect(transaction).to receive(:start_event)

        subscriber.started(event)
      end
    end

    describe "#succeeded" do
      let(:event) { double }

      it "should finish the event" do
        expect(subscriber).to receive(:finish).with("SUCCEEDED", event)

        subscriber.succeeded(event)
      end
    end

    describe "#failed" do
      let(:event) { double }

      it "should finish the event" do
        expect(subscriber).to receive(:finish).with("FAILED", event)

        subscriber.failed(event)
      end
    end

    describe "#finish" do
      let(:command) { { "foo" => "?" } }
      let(:event) do
        double(
          :request_id    => 2,
          :command_name  => :find,
          :database_name => "test",
          :duration      => 0.9919
        )
      end

      before do
        store = transaction.store("mongo_driver")
        store[2] = command
      end

      it "should get the query from the store" do
        expect(transaction).to receive(:store).with("mongo_driver").and_return(command)

        subscriber.finish("SUCCEEDED", event)
      end
    end
  end

  describe "instrumenting a finished query" do
    let(:started_event) do
      double(
        :request_id   => 2,
        :command_name => "find",
        :command      => { "foo" => "bar" }
      )
    end
    let(:finish_event) do
      double(
        :request_id    => 2,
        :command_name  => :find,
        :database_name => "test",
        :duration      => 0.9919
      )
    end

    def perform
      subscriber.started(started_event)
      subscriber.finish("SUCCEEDED", finish_event)
    end

    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)

      expect(Appsignal).to receive(:add_distribution_value).with(
        "mongodb_query_duration",
        0.9919,
        :database => "test"
      ).and_call_original

      perform

      expect(transaction).to include_event(
        "name" => "query.mongodb",
        "title" => "find | test | SUCCEEDED",
        "body" => "{\"foo\":\"?\"}"
      )
    end

    it "in collector mode", :collector_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform
      Appsignal::Transaction.complete_current!

      span = event_spans.find { |s| s.name == "query.mongodb" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(span.attributes["appsignal.title"]).to eq("find | test | SUCCEEDED")
      expect(span.attributes["appsignal.body"]).to eq("{\"foo\":\"?\"}")

      snapshot = metric_snapshot("mongodb_query_duration")
      expect(snapshot).not_to be_nil
      expect(snapshot.data_points.first.sum).to be_within(0.0001).of(0.9919)
      expect(snapshot.data_points.first.attributes).to eq("database" => "test")
    end

    describe "instrumenting a failed query" do
      let(:started_event) { command_started_event(:request_id => 2) }
      let(:failed_event) { command_failed_event(started_event, :request_id => 2) }

      def perform
        subscriber.started(started_event)
        subscriber.failed(failed_event)
      end

      it "records the query as an event" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

        perform

        expect(transaction).to include_event(
          "name" => "query.mongodb",
          "title" => "find | test | FAILED",
          "body" => "{\"foo\":\"?\"}"
        )
      end
    end

    # The subscriber guards on a current, unpaused transaction before touching
    # the extension, so nothing is recorded otherwise.
    describe "without an active transaction" do
      def perform
        started = command_started_event
        subscriber.started(started)
        subscriber.succeeded(command_succeeded_event(started))
      end

      it "does not record anything" do
        start_agent
        expect(Appsignal::Extension).to_not receive(:start_event)
        expect(Appsignal::Extension).to_not receive(:finish_event)
        expect(Appsignal).to_not receive(:add_distribution_value)

        perform
      end
    end

    describe "when the transaction is paused" do
      def perform
        started = command_started_event
        subscriber.started(started)
        subscriber.succeeded(command_succeeded_event(started))
      end

      it "does not record anything" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        transaction.pause!

        expect(Appsignal::Extension).to_not receive(:start_event)
        expect(Appsignal::Extension).to_not receive(:finish_event)
        expect(Appsignal).to_not receive(:add_distribution_value)

        perform
      end
    end
  end
end
