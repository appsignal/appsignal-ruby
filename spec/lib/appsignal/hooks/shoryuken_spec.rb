describe Appsignal::Hooks::ShoryukenMiddleware do
  class DemoShoryukenWorker
  end

  let(:time) { "2010-01-01 10:01:00UTC" }
  let(:worker_instance) { DemoShoryukenWorker.new }
  let(:queue) { "some-funky-queue-name" }
  let(:sqs_msg) { double(:message_id => "msg1", :attributes => {}) }
  let(:body) { {} }
  before(:context) { start_agent }
  around { |example| keep_transactions { example.run } }

  def perform_job(&block)
    block ||= lambda {}
    Timecop.freeze(Time.parse(time)) do
      Appsignal::Hooks::ShoryukenMiddleware.new.call(
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
        allow_any_instance_of(Appsignal::Transaction).to receive(:set_queue_start).and_call_original
        expect { perform_job }.to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to be_completed
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "action" => "DemoShoryukenWorker#perform",
          "id" => kind_of(String), # AppSignal generated id
          "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
          "error" => nil
        )
        expect(transaction_hash["events"].first).to include(
          "allocation_count" => kind_of(Integer),
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "child_allocation_count" => kind_of(Integer),
          "child_duration" => kind_of(Float),
          "child_gc_duration" => kind_of(Float),
          "count" => 1,
          "gc_duration" => kind_of(Float),
          "start" => kind_of(Float),
          "duration" => kind_of(Float),
          "name" => "perform_job.shoryuken",
          "title" => ""
        )
        expect(transaction_hash["sample_data"]).to include(
          "params" => { "foo" => "Foo", "bar" => "Bar" },
          "metadata" => {
            "message_id" => "msg1",
            "queue" => queue,
            "SentTimestamp" => sent_timestamp
          }
        )
        expect(transaction).to have_received(:set_queue_start).with(sent_timestamp)
      end

      context "with parameter filtering" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end
        after do
          Appsignal.config[:filter_parameters] = []
        end

        it "filters selected arguments" do
          perform_job

          transaction_hash = last_transaction.to_h
          expect(transaction_hash["sample_data"]).to include(
            "params" => { "foo" => "[FILTERED]", "bar" => "Bar" }
          )
        end
      end
    end

    context "with a string as an argument" do
      let(:body) { "foo bar" }

      it "handles string arguments" do
        perform_job

        transaction_hash = last_transaction.to_h
        expect(transaction_hash["sample_data"]).to include(
          "params" => { "params" => body }
        )
      end
    end

    context "with primitive type as argument" do
      let(:body) { 1 }

      it "handles primitive types as arguments" do
        perform_job

        transaction_hash = last_transaction.to_h
        expect(transaction_hash["sample_data"]).to include(
          "params" => { "params" => body }
        )
      end
    end
  end

  context "with exception" do
    it "sets the exception on the transaction" do
      expect do
        expect do
          perform_job { raise ExampleException, "error message" }
        end.to raise_error(ExampleException)
      end.to change { created_transactions.length }.by(1)

      transaction = last_transaction
      expect(transaction).to be_completed
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "action" => "DemoShoryukenWorker#perform",
        "id" => kind_of(String), # AppSignal generated id
        "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
        "error" => {
          "name" => "ExampleException",
          "message" => "error message",
          "backtrace" => kind_of(String)
        }
      )
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
      allow_any_instance_of(Appsignal::Transaction).to receive(:set_queue_start).and_call_original
      expect do
        perform_job {} # rubocop:disable Lint/EmptyBlock
      end.to change { created_transactions.length }.by(1)

      transaction = last_transaction
      expect(transaction).to be_completed
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "action" => "DemoShoryukenWorker#perform",
        "id" => kind_of(String), # AppSignal generated id
        "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
        "error" => nil
      )
      expect(transaction_hash["events"].first).to include(
        "allocation_count" => kind_of(Integer),
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "child_allocation_count" => kind_of(Integer),
        "child_duration" => kind_of(Float),
        "child_gc_duration" => kind_of(Float),
        "count" => 1,
        "gc_duration" => kind_of(Float),
        "start" => kind_of(Float),
        "duration" => kind_of(Float),
        "name" => "perform_job.shoryuken",
        "title" => ""
      )
      expect(transaction_hash["sample_data"]).to include(
        "params" => {
          "msg2" => "foo bar",
          "msg1" => { "id" => "123", "foo" => "Foo", "bar" => "Bar" }
        },
        "metadata" => {
          "batch" => true,
          "queue" => "some-funky-queue-name",
          "SentTimestamp" => sent_timestamp.to_s # Earliest/oldest timestamp from messages
        }
      )
      # Queue time based on earliest/oldest timestamp from messages
      expect(transaction).to have_received(:set_queue_start).with(sent_timestamp)
    end
  end
end

describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    before(:context) do
      module Shoryuken
        def self.configure_server
        end
      end
      Appsignal::Hooks::ShoryukenHook.new.install
    end

    after(:context) do
      Object.send(:remove_const, :Shoryuken)
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end
  end

  context "without shoryuken" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
