describe Appsignal::Hooks::SidekiqPlugin do
  let(:worker) { double }
  let(:queue) { double }
  let(:current_transaction) { background_job_transaction }
  let(:item) do
    {
      "class"       => "TestClass",
      "retry_count" => 0,
      "queue"       => "default",
      "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC"),
      "args"        => ["Model", 1],
      "extra"       => "data"
    }
  end
  let(:plugin) { Appsignal::Hooks::SidekiqPlugin.new }

  before do
    Appsignal::Transaction.stub(:current => current_transaction)
    start_agent
  end

  context "with a performance call" do
    it "should wrap in a transaction with the correct params" do
      Appsignal.should_receive(:monitor_transaction).with(
        "perform_job.sidekiq",
        :class    => "TestClass",
        :method   => "perform",
        :metadata => {
          "retry_count" => "0",
          "queue"       => "default",
          "extra"       => "data"
        },
        :params      => ["Model", "1"],
        :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
        :queue_time  => 60000.to_f
      )
    end

    context "when wrapped by ActiveJob" do
      let(:item) do
        {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "wrapped" => "TestClass",
          "queue" => "default",
          "args" => [{
            "job_class" => "TestJob",
            "job_id" => "23e79d48-6966-40d0-b2d4-f7938463a263",
            "queue_name" => "default",
            "arguments" => ["Model", 1],
          }],
          "retry" => true,
          "jid" => "efb140489485999d32b5504c",
          "created_at" => Time.parse("01-01-2001 10:00:00UTC").to_f,
          "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f
        }
      end

      it "should wrap in a transaction with the correct params" do
        Appsignal.should_receive(:monitor_transaction).with(
          "perform_job.sidekiq",
          :class    => "TestClass",
          :method   => "perform",
          :metadata => {
            "queue" => "default"
          },
          :params      => ["Model", "1"],
          :queue_start => Time.parse("01-01-2001 10:00:00UTC").to_f,
          :queue_time  => 60000.to_f
        )
      end
    end

    after do
      Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
        Appsignal::Hooks::SidekiqPlugin.new.call(worker, item, queue) do
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
          Appsignal::Hooks::SidekiqPlugin.new.call(worker, item, queue) do
            raise error
          end
        end
      rescue VerySpecificError
      end
    end
  end

  describe "#formatted_data" do
    let(:item) do
      {
        "foo"   => "bar",
        "class" => "TestClass",
      }
    end

    it "should only add items to the hash that do not appear in JOB_KEYS" do
      plugin.formatted_metadata(item).should eq("foo" => "bar")
    end
  end
end

describe Appsignal::Hooks::SidekiqHook do
  context "with sidekiq" do
    before :all do
      module Sidekiq
        def self.configure_server
        end
      end
      Appsignal::Hooks::SidekiqHook.new.install
    end
    after(:all) { Object.send(:remove_const, :Sidekiq) }

    its(:dependencies_present?) { should be_true }
  end

  context "without sidekiq" do
    its(:dependencies_present?) { should be_false }
  end
end
