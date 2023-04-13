require "appsignal/integrations/mongo_ruby_driver"
describe Appsignal::Hooks::MongoMonitorSubscriber do
  let(:subscriber) { Appsignal::Hooks::MongoMonitorSubscriber.new }

  context "with transaction" do
    let!(:transaction) do
      Appsignal::Transaction.create("1", "http_request", {}, {})
    end

    describe "#started" do
      let(:event) do
        double(
          :request_id   => 1,
          :command_name => "find",
          :command      => { "foo" => "bar" }
        )
      end

      it "should sanitize command" do
        # TODO: additional curly brackets required for issue
        # https://github.com/rspec/rspec-mocks/issues/1460
        expect(Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter)
          .to receive(:format).with("find", { "foo" => "bar" })
        subscriber.started(event)
      end

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

      it "should emit a measurement" do
        expect(Appsignal).to receive(:add_distribution_value).with(
          "mongodb_query_duration",
          0.9919,
          :database => "test"
        ).and_call_original

        subscriber.finish("SUCCEEDED", event)
      end

      it "should get the query from the store" do
        expect(transaction).to receive(:store).with("mongo_driver").and_return(command)

        subscriber.finish("SUCCEEDED", event)
      end

      it "should finish the transaction in the extension" do
        expect(transaction).to receive(:finish_event).with(
          "query.mongodb",
          "find | test | SUCCEEDED",
          Appsignal::Utils::Data.generate("foo" => "?"),
          0
        )

        subscriber.finish("SUCCEEDED", event)
      end
    end
  end

  context "without transaction" do
    before do
      allow(Appsignal::Transaction).to receive(:current)
        .and_return(Appsignal::Transaction::NilTransaction.new)
    end

    it "should not attempt to start an event" do
      expect(Appsignal::Extension).to_not receive(:start_event)

      subscriber.started(double)
    end

    it "should not attempt to finish an event" do
      expect(Appsignal::Extension).to_not receive(:finish_event)

      subscriber.finish("SUCCEEDED", double)
    end

    it "should not attempt to send duration metrics" do
      expect(Appsignal).to_not receive(:add_distribution_value)

      subscriber.finish("SUCCEEDED", double)
    end
  end

  context "when appsignal is paused" do
    let(:transaction) { double(:paused? => true, :nil_transaction? => false) }
    before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

    it "should not attempt to start an event" do
      expect(Appsignal::Extension).to_not receive(:start_event)

      subscriber.started(double)
    end

    it "should not attempt to finish an event" do
      expect(Appsignal::Extension).to_not receive(:finish_event)

      subscriber.finish("SUCCEEDED", double)
    end

    it "should not attempt to send duration metrics" do
      expect(Appsignal).to_not receive(:add_distribution_value)

      subscriber.finish("SUCCEEDED", double)
    end
  end
end
