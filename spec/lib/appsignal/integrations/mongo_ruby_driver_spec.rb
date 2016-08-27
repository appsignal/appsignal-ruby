require 'appsignal/integrations/mongo_ruby_driver'
describe Appsignal::Hooks::MongoMonitorSubscriber do
  let(:subscriber) { Appsignal::Hooks::MongoMonitorSubscriber.new }

  context "with transaction" do
    let!(:transaction) do
      Appsignal::Transaction.create('1', 'http_request', {}, {})
    end

    describe "#started" do
      let(:event) do
        double(
          :request_id   => 1,
          :command_name => 'find',
          :command      => {'foo' => 'bar'}
        )
      end

      it "should sanitize command" do
        Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter
          .should receive(:format).with('find', {'foo' => 'bar'})

        subscriber.started(event)
      end

      it "should store command on the transaction" do
        subscriber.started(event)

        transaction.store('mongo_driver').should eq({1 => {'foo' => '?'}})
      end

      it "should start an event in the extension" do
        transaction.should receive(:start_event)

        subscriber.started(event)
      end
    end

    describe "#succeeded" do
      let(:event) { double }

      it "should finish the event" do
        subscriber.should receive(:finish).with('SUCCEEDED', event)

        subscriber.succeeded(event)
      end
    end

    describe "#failed" do
      let(:event) { double }

      it "should finish the event" do
        subscriber.should receive(:finish).with('FAILED', event)

        subscriber.failed(event)
      end
    end

    describe "#finish" do
      let(:command) { {'foo' => '?'} }
      let(:event) do
        double(
          :request_id    => 2,
          :command_name  => :find,
          :database_name => 'test'
        )
      end

      before do
        store = transaction.store('mongo_driver')
        store[2] = command
      end

      it "should get the query from the store" do
        transaction.should receive(:store).with('mongo_driver').and_return(command)

        subscriber.finish('SUCCEEDED', event)
      end

      it "should finish the transaction in the extension" do
        transaction.should receive(:finish_event).with(
          'query.mongodb',
          'find | test | SUCCEEDED',
          "{\"foo\":\"?\"}",
          0
        )

        subscriber.finish('SUCCEEDED', event)
      end
    end
  end

  context "without transaction" do
    before do
      Appsignal::Transaction.stub(
        :current => Appsignal::Transaction::NilTransaction.new
      )
    end

    it "should not attempt to start an event" do
      Appsignal::Extension.should_not receive(:start_event)

      subscriber.started(double)
    end

    it "should not attempt to finish an event" do
      Appsignal::Extension.should_not receive(:finish_event)

      subscriber.finish('SUCCEEDED', double)
    end
  end

  context "when appsignal is paused" do
    let(:transaction) { double(:paused? => true, :nil_transaction? => false) }
    before { Appsignal::Transaction.stub(:current => transaction) }

    it "should not attempt to start an event" do
      Appsignal::Extension.should_not receive(:start_event)

      subscriber.started(double)
    end

    it "should not attempt to finish an event" do
      Appsignal::Extension.should_not receive(:finish_event)

      subscriber.finish('SUCCEEDED', double)
    end
  end
end
