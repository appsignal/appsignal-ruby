require "appsignal/integrations/mongo_ruby_driver"

  # White-box unit tests of the subscriber's interaction with the Transaction
  # API and the C-extension. Pinned to :agent_mode: they assert extension
  # mechanics (`start_event`/`finish_event`) that only apply to the agent
  # backend; the OTel-backed transaction output is covered by "instrumenting a
  # finished query" below in both modes. `start_agent` comes from the mode
  # context, so it is not started here.
  context "with transaction", :agent_mode, :manual_start do
    let(:transaction) { http_request_transaction }
    before do
      set_current_transaction(transaction)
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

      it "should sanitize command" do
        start_agent
        # TODO: additional curly brackets required for issue
        # https://github.com/rspec/rspec-mocks/issues/1460
        expect(Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter)
          .to receive(:format).with("find", { "foo" => "bar" })
        subscriber.started(event)
      end

      it "should store command on the transaction" do
        start_agent
        subscriber.started(event)

        expect(transaction.store("mongo_driver")).to eq(1 => { "foo" => "?" })
      end

      it "should start an event in the extension" do
        start_agent
        expect(transaction).to receive(:start_event)

        subscriber.started(event)
      end
    end

    describe "#succeeded" do
      let(:event) { double }

      it "should finish the event" do
        start_agent
        expect(subscriber).to receive(:finish).with("SUCCEEDED", event)

        subscriber.succeeded(event)
      end
    end

    describe "#failed" do
      let(:event) { double }

      it "should finish the event" do
        start_agent
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
        start_agent
        expect(transaction).to receive(:store).with("mongo_driver").and_return(command)

        subscriber.finish("SUCCEEDED", event)
      end
    end
  end

  describe "instrumenting a finished query", :manual_start do
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

  context "without transaction", :agent_mode, :manual_start do
    before do
      allow(Appsignal::Transaction).to receive(:current)
        .and_return(Appsignal::Transaction::NilTransaction.new)
    end

    it "should not attempt to start an event" do
      start_agent
      expect(Appsignal::Extension).to_not receive(:start_event)

      it "does not record anything" do
        start_agent
        expect(Appsignal::Extension).to_not receive(:start_event)
        expect(Appsignal::Extension).to_not receive(:finish_event)
        expect(Appsignal).to_not receive(:add_distribution_value)

        perform
      end
    end

    it "should not attempt to finish an event" do
      start_agent
      expect(Appsignal::Extension).to_not receive(:finish_event)

      it "does not record anything" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        transaction.pause!

    it "should not attempt to send duration metrics" do
      start_agent
      expect(Appsignal).to_not receive(:add_distribution_value)

      subscriber.finish("SUCCEEDED", double)
    end
  end

  context "when appsignal is paused", :agent_mode, :manual_start do
    let(:transaction) { double(:paused? => true, :nil_transaction? => false) }
    before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

    it "should not attempt to start an event" do
      start_agent
      expect(Appsignal::Extension).to_not receive(:start_event)

      subscriber.started(double)
    end

    it "should not attempt to finish an event" do
      start_agent
      expect(Appsignal::Extension).to_not receive(:finish_event)

      subscriber.finish("SUCCEEDED", double)
    end

    it "should not attempt to send duration metrics" do
      start_agent
      expect(Appsignal).to_not receive(:add_distribution_value)

      subscriber.finish("SUCCEEDED", double)
    end
  end
end
