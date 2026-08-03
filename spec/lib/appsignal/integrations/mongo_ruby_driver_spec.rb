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

    # `failure` is the error document MongoDB replied with, which carries its
    # own code for the error in the `code` field.
    def command_failed_event( # rubocop:disable Metrics/ParameterLists
      started_event, request_id: 1, command_name: "find",
      database_name: "test", duration: 0.9919,
      failure: { "code" => 26, "codeName" => "NamespaceNotFound" }
    )
      Mongo::Monitoring::Event::CommandFailed.new(
        command_name, database_name, address, request_id, 1, "message", failure, duration,
        :started_event => started_event
      )
    end

    # `started` sanitizes the command and stores it on the transaction, keyed by
    # request id, for the matching `succeeded`/`failed` to pick up. The store
    # lives on the base transaction (not the backend), so this is identical in
    # both modes.
    it_in_both_modes "stores the sanitized command on the transaction" do
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

      it "in agent mode", :agent_mode do
        start_agent
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
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_span_for("query.mongodb")
        expect(span).not_to be_nil
        expect(span.name).to eq("query.mongodb (find | test | SUCCEEDED)")
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(event_category(span)).to eq("query.mongodb")
        expect(scope_of(span)).to eq(["appsignal-ruby/mongo", Appsignal::VERSION])
        expect(span.attributes["db.system.name"]).to eq("mongodb")
        expect(span.attributes["db.operation.name"]).to eq("find")
        expect(span.attributes["db.namespace"]).to eq("test")
        expect(span.attributes["server.address"]).to eq("127.0.0.1")
        expect(span.attributes["server.port"]).to eq(27_017)
        # This command names no collection, so none is reported.
        expect(span.attributes).not_to have_key("db.collection.name")
        expect(span.attributes["appsignal.body"]).to eq("{\"foo\":\"?\"}")
        expect(span.attributes).not_to have_key("db.response.status_code")

        snapshot = metric_snapshot("mongodb_query_duration")
        expect(snapshot).not_to be_nil
        expect(snapshot.data_points.first.sum).to be_within(0.0001).of(0.9919)
        expect(snapshot.data_points.first.attributes).to eq("database" => "test")
      end
    end

    describe "instrumenting a query on a collection" do
      let(:started_event) do
        command_started_event(
          :request_id => 2,
          :command => { "find" => "users", "filter" => { "foo" => "bar" } }
        )
      end
      let(:succeeded_event) { command_succeeded_event(started_event, :request_id => 2) }

      def perform
        subscriber.started(started_event)
        subscriber.succeeded(succeeded_event)
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

        perform

        expect(transaction).to include_event(
          "name" => "query.mongodb",
          "title" => "find | test | SUCCEEDED",
          "body" => "{\"find\":\"users\",\"filter\":{\"foo\":\"?\"}}"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_span_for("query.mongodb")
        expect(span).not_to be_nil
        # MongoDB names the collection in the field named after the command, so
        # a query on one reports it.
        expect(span.attributes["db.collection.name"]).to eq("users")
        expect(span.attributes["db.operation.name"]).to eq("find")
      end
    end

    describe "instrumenting a failed query" do
      let(:started_event) { command_started_event(:request_id => 2) }
      let(:failed_event) { command_failed_event(started_event, :request_id => 2) }

      def perform
        subscriber.started(started_event)
        subscriber.failed(failed_event)
      end

      it "in agent mode", :agent_mode do
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

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_span_for("query.mongodb")
        expect(span).not_to be_nil
        expect(span.name).to eq("query.mongodb (find | test | FAILED)")
        expect(span.kind).to eq(:client)
        expect(event_category(span)).to eq("query.mongodb")
        expect(scope_of(span)).to eq(["appsignal-ruby/mongo", Appsignal::VERSION])
        expect(span.attributes["db.system.name"]).to eq("mongodb")
        expect(span.attributes["appsignal.body"]).to eq("{\"foo\":\"?\"}")
        # The query failed, and MongoDB reported its own code for the error in
        # the document it replied with.
        expect(span.attributes["db.response.status_code"]).to eq("26")
      end
    end

    describe "instrumenting a query that failed without an error code" do
      let(:started_event) { command_started_event(:request_id => 2) }
      let(:failed_event) do
        command_failed_event(started_event, :request_id => 2, :failure => {})
      end

      def perform
        subscriber.started(started_event)
        subscriber.failed(failed_event)
      end

      it "in agent mode", :agent_mode do
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

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_span_for("query.mongodb")
        expect(span).not_to be_nil
        # A dropped connection is a failure MongoDB never replied to, so there
        # is no code to report.
        expect(span.attributes).to_not have_key("db.response.status_code")
      end
    end

    # The subscriber guards (`return unless current?` / `return if paused?`) run
    # before any backend is touched, so "no instrumentation is recorded" is an
    # invariant in both modes. Agent mode asserts no extension calls; collector
    # mode asserts nothing is exported.
    describe "without an active transaction" do
      def perform
        started = command_started_event
        subscriber.started(started)
        subscriber.succeeded(command_succeeded_event(started))
      end

      it "in agent mode", :agent_mode do
        start_agent
        expect(Appsignal::Extension).to_not receive(:start_event)
        expect(Appsignal::Extension).to_not receive(:finish_event)
        expect(Appsignal).to_not receive(:add_distribution_value)

        perform
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect(span_exporter.finished_spans).to be_empty
        expect(metric_snapshot("mongodb_query_duration")).to be_nil
      end
    end

    describe "when the transaction is paused" do
      def perform
        started = command_started_event
        subscriber.started(started)
        subscriber.succeeded(command_succeeded_event(started))
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        transaction.pause!

        expect(Appsignal::Extension).to_not receive(:start_event)
        expect(Appsignal::Extension).to_not receive(:finish_event)
        expect(Appsignal).to_not receive(:add_distribution_value)

        perform
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        transaction.pause!

        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans).to be_empty
        expect(metric_snapshot("mongodb_query_duration")).to be_nil
      end
    end
  end
end
