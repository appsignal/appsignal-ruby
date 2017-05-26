describe Appsignal::Hooks::ShoryukenMiddleware do
  let(:current_transaction) { background_job_transaction }

  class DemoShoryukenWorker
  end

  let(:worker_instance) { DemoShoryukenWorker.new }
  let(:queue) { double }
  let(:sqs_msg) { double(:attributes => {}) }
  let(:body) { {} }

  before do
    allow(Appsignal::Transaction).to receive(:current).and_return(current_transaction)
    start_agent
  end

  context "with a performance call" do
    let(:queue) { "some-funky-queue-name" }
    let(:sqs_msg) do
      double(:attributes => { "SentTimestamp" => Time.parse("1976-11-18 0:00:00UTC").to_i * 1000 })
    end

    context "with complex argument" do
      let(:body) do
        {
          :foo => "Foo",
          :bar => "Bar"
        }
      end
      after do
        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            # nothing
          end
        end
      end

      it "wraps the job in a transaction with the correct params" do
        expect(Appsignal).to receive(:monitor_transaction).with(
          "perform_job.shoryuken",
          :class => "DemoShoryukenWorker",
          :method => "perform",
          :metadata => {
            :queue => "some-funky-queue-name",
            "SentTimestamp" => 217_123_200_000
          },
          :params => {
            :foo => "Foo",
            :bar => "Bar"
          },
          :queue_start => Time.parse("1976-11-18 0:00:00UTC").utc
        )
      end

      context "with parameter filtering" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end

        it "filters selected arguments" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.shoryuken",
            :class => "DemoShoryukenWorker",
            :method => "perform",
            :metadata => {
              :queue => "some-funky-queue-name",
              "SentTimestamp" => 217_123_200_000
            },
            :params => {
              :foo => "[FILTERED]",
              :bar => "Bar"
            },
            :queue_start => Time.parse("1976-11-18 0:00:00UTC").utc
          )
        end
      end
    end

    context "with a string as an argument" do
      let(:body) { "foo bar" }

      it "handles string arguments" do
        expect(Appsignal).to receive(:monitor_transaction).with(
          "perform_job.shoryuken",
          :class => "DemoShoryukenWorker",
          :method => "perform",
          :metadata => {
            :queue => "some-funky-queue-name",
            "SentTimestamp" => 217_123_200_000
          },
          :params => { :params => body },
          :queue_start => Time.parse("1976-11-18 0:00:00UTC").utc
        )

        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            # nothing
          end
        end
      end
    end

    context "with primitive type as argument" do
      let(:body) { 1 }

      it "handles primitive types as arguments" do
        expect(Appsignal).to receive(:monitor_transaction).with(
          "perform_job.shoryuken",
          :class => "DemoShoryukenWorker",
          :method => "perform",
          :metadata => {
            :queue => "some-funky-queue-name",
            "SentTimestamp" => 217_123_200_000
          },
          :params => { :params => body },
          :queue_start => Time.parse("1976-11-18 0:00:00UTC").utc
        )

        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            # nothing
          end
        end
      end
    end
  end

  context "with exception" do
    let(:transaction) do
      Appsignal::Transaction.new(
        SecureRandom.uuid,
        Appsignal::Transaction::BACKGROUND_JOB,
        Appsignal::Transaction::GenericRequest.new({})
      )
    end

    before do
      allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
      expect(Appsignal::Transaction).to receive(:create)
        .with(
          kind_of(String),
          Appsignal::Transaction::BACKGROUND_JOB,
          kind_of(Appsignal::Transaction::GenericRequest)
        ).and_return(transaction)
    end

    it "sets the exception on the transaction" do
      expect(transaction).to receive(:set_error).with(VerySpecificError)
    end

    after do
      expect do
        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            raise VerySpecificError
          end
        end
      end.to raise_error(VerySpecificError)
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
