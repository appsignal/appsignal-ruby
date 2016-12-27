describe Appsignal::Hooks::ShoryukenMiddleware do
  let(:current_transaction) { background_job_transaction }

  let(:worker_instance) { double }
  let(:queue) { double }
  let(:sqs_msg) { double(:attributes => {}) }
  let(:body) { {} }

  before do
    Appsignal::Transaction.stub(:current => current_transaction)
    start_agent
  end

  context "with a performance call" do
    let(:queue) { "some-funky-queue-name" }
    let(:sqs_msg) do
      double(:attributes => { "SentTimestamp" => Time.parse("1976-11-18 0:00:00UTC").to_i * 1000 })
    end
    let(:body) do
      {
        "job_class" => "TestClass",
        "arguments" => ["Model", "1"]
      }
    end

    it "should wrap in a transaction with the correct params" do
      Appsignal.should_receive(:monitor_transaction).with(
        "perform_job.shoryuken",
        :class => "TestClass",
        :method => "perform",
        :metadata => {
          :queue => "some-funky-queue-name",
          "SentTimestamp" => 217123200000
        },
        :params => ["Model", "1"],
        :queue_start => Time.parse("1976-11-18 0:00:00UTC").utc
      )
    end

    after do
      Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
        Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
          # nothing
        end
      end
    end
  end

  context "with an erroring call" do
    let(:error) { VerySpecificError.new }

    it "should add the exception to appsignal" do
      Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
    end

    after do
      begin
        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            raise error
          end
        end
      rescue VerySpecificError
      end
    end
  end
end

describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    before(:all) do
      module Shoryuken
        def self.configure_server
        end
      end
      Appsignal::Hooks::ShoryukenHook.new.install
    end

    after(:all) do
      Object.send(:remove_const, :Shoryuken)
    end

    its(:dependencies_present?) { should be_true }
  end

  context "without shoryuken" do
    its(:dependencies_present?) { should be_false }
  end
end
