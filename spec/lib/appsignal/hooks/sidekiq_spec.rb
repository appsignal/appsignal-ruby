describe Appsignal::Hooks::SidekiqPlugin, :with_yaml_parse_error => false do
  class DelayedTestClass; end

  let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
  let(:worker) { anything }
  let(:queue) { anything }
  let(:given_args) do
    [
      "foo",
      {
        :foo => "Foo",
        :bar => "Bar",
        "baz" => { 1 => :foo }
      }
    ]
  end
  let(:expected_args) do
    [
      "foo",
      {
        "foo" => "Foo",
        "bar" => "Bar",
        "baz" => { "1" => "foo" }
      }
    ]
  end
  let(:job_class) { "TestClass" }
  let(:item) do
    {
      "jid"         => "b4a577edbccf1d805744efa9",
      "class"       => job_class,
      "retry_count" => 0,
      "queue"       => "default",
      "created_at"  => Time.parse("2001-01-01 10:00:00UTC").to_f,
      "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
      "args"        => given_args,
      "extra"       => "data"
    }
  end
  let(:plugin) { Appsignal::Hooks::SidekiqPlugin.new }
  let(:test_store) { {} }
  let(:log) { StringIO.new }
  before do
    start_agent
    Appsignal.logger = test_logger(log)

    # Stub calls to extension, because that would remove the transaction
    # from the extension.
    allow_any_instance_of(Appsignal::Extension::Transaction).to receive(:finish).and_return(true)
    allow_any_instance_of(Appsignal::Extension::Transaction).to receive(:complete)

    # Stub removal of current transaction from current thread so we can fetch
    # it later.
    expect(Appsignal::Transaction).to receive(:clear_current_transaction!) do
      transaction = Thread.current[:appsignal_transaction]
      test_store[:transaction] = transaction if transaction
    end
  end
  after :with_yaml_parse_error => false do
    expect(log_contents(log)).to_not contains_log(:warn, "Unable to load YAML")
  end
  after { clear_current_transaction! }

  shared_examples "sidekiq metadata" do
    describe "internal Sidekiq job values" do
      it "does not save internal Sidekiq values as metadata on transaction" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash["metadata"].keys)
          .to_not include(*Appsignal::Hooks::SidekiqPlugin::JOB_KEYS)
      end
    end

    context "with parameter filtering" do
      before do
        Appsignal.config = project_fixture_config("production")
        Appsignal.config[:filter_parameters] = ["foo"]
      end

      it "filters selected arguments" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash["sample_data"]).to include(
          "params" => [
            "foo",
            {
              "foo" => "[FILTERED]",
              "bar" => "Bar",
              "baz" => { "1" => "foo" }
            }
          ]
        )
      end
    end

    context "with encrypted arguments" do
      before do
        item["encrypt"] = true
        item["args"] << "super secret value" # Last argument will be replaced
      end

      it "replaces the last argument (the secret bag) with an [encrypted data] string" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash["sample_data"]).to include(
          "params" => expected_args << "[encrypted data]"
        )
      end
    end

    context "when using the Sidekiq delayed extension" do
      let(:item) do
        {
          "jid" => "efb140489485999d32b5504c",
          "class" => "Sidekiq::Extensions::DelayedClass",
          "queue" => "default",
          "args" => [
            "---\n- !ruby/class 'DelayedTestClass'\n- :foo_method\n- - :bar: baz\n"
          ],
          "retry" => true,
          "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
          "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
          "extra" => "data"
        }
      end

      it "uses the delayed class and method name for the action" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash["action"]).to eq("DelayedTestClass.foo_method")
        expect(transaction_hash["sample_data"]).to include(
          "params" => ["bar" => "baz"]
        )
      end

      context "when job arguments is a malformed YAML object", :with_yaml_parse_error => true do
        before { item["args"] = [] }

        it "logs a warning and uses the default argument" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash["action"]).to eq("Sidekiq::Extensions::DelayedClass#perform")
          expect(transaction_hash["sample_data"]).to include("params" => [])
          expect(log_contents(log)).to contains_log(:warn, "Unable to load YAML")
        end
      end
    end

    context "when using the Sidekiq ActiveRecord instance delayed extension" do
      let(:item) do
        {
          "jid" => "efb140489485999d32b5504c",
          "class" => "Sidekiq::Extensions::DelayedModel",
          "queue" => "default",
          "args" => [
            "---\n- !ruby/object:DelayedTestClass {}\n- :foo_method\n- - :bar: :baz\n"
          ],
          "retry" => true,
          "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
          "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
          "extra" => "data"
        }
      end

      it "uses the delayed class and method name for the action" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash["action"]).to eq("DelayedTestClass#foo_method")
        expect(transaction_hash["sample_data"]).to include(
          "params" => ["bar" => "baz"]
        )
      end

      context "when job arguments is a malformed YAML object", :with_yaml_parse_error => true do
        before { item["args"] = [] }

        it "logs a warning and uses the default argument" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash["action"]).to eq("Sidekiq::Extensions::DelayedModel#perform")
          expect(transaction_hash["sample_data"]).to include("params" => [])
          expect(log_contents(log)).to contains_log(:warn, "Unable to load YAML")
        end
      end
    end

    context "when using ActiveJob" do
      let(:item) do
        {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "wrapped" => "ActiveJobTestClass",
          "queue" => "default",
          "args" => [{
            "job_class" => "ActiveJobTestJob",
            "job_id" => "23e79d48-6966-40d0-b2d4-f7938463a263",
            "queue_name" => "default",
            "arguments" => [
              "foo", { "foo" => "Foo", "bar" => "Bar", "baz" => { 1 => :bar } }
            ]
          }],
          "retry" => true,
          "jid" => "efb140489485999d32b5504c",
          "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
          "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f
        }
      end

      it "creates a transaction with events" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "id" => kind_of(String),
          "action" => "ActiveJobTestClass#perform",
          "error" => nil,
          "namespace" => namespace,
          "metadata" => {
            "queue" => "default"
          },
          "sample_data" => {
            "environment" => {},
            "params" => [
              "foo",
              {
                "foo" => "Foo",
                "bar" => "Bar",
                "baz" => { "1" => "bar" }
              }
            ],
            "tags" => {}
          }
        )
        # TODO: Not available in transaction.to_h yet.
        # https://github.com/appsignal/appsignal-agent/issues/293
        expect(transaction.request.env).to eq(
          :queue_start => Time.parse("2001-01-01 10:00:00UTC").to_f
        )
        expect_transaction_to_have_sidekiq_event(transaction_hash)
      end

      context "with ActionMailer job" do
        let(:item) do
          {
            "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
            "wrapped" => "ActionMailer::DeliveryJob",
            "queue" => "default",
            "args" => [{
              "job_class" => "ActiveMailerTestJob",
              "job_id" => "23e79d48-6966-40d0-b2d4-f7938463a263",
              "queue_name" => "default",
              "arguments" => [
                "MailerClass", "mailer_method", "deliver_now",
                "foo", { "foo" => "Foo", "bar" => "Bar", "baz" => { 1 => :bar } }
              ]
            }],
            "retry" => true,
            "jid" => "efb140489485999d32b5504c",
            "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
            "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f
          }
        end

        it "creates a transaction for the ActionMailer class" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "id" => kind_of(String),
            "action" => "MailerClass#mailer_method",
            "error" => nil,
            "namespace" => namespace,
            "metadata" => {
              "queue" => "default"
            },
            "sample_data" => {
              "environment" => {},
              "params" => [
                "foo",
                {
                  "foo" => "Foo",
                  "bar" => "Bar",
                  "baz" => { "1" => "bar" }
                }
              ],
              "tags" => {}
            }
          )
        end
      end

      context "with parameter filtering" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end

        it "filters selected arguments" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash["sample_data"]).to include(
            "params" => [
              "foo",
              {
                "foo" => "[FILTERED]",
                "bar" => "Bar",
                "baz" => { "1" => "bar" }
              }
            ]
          )
        end
      end

      context "when Sidekiq job payload is missing the 'wrapped' value" do
        let(:item) do
          {
            "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
            "queue" => "default",
            "args" => [first_argument],
            "retry" => true,
            "jid" => "efb140489485999d32b5504c",
            "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
            "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f
          }
        end
        before { perform_job }

        context "when the first argument is not a Hash object" do
          let(:first_argument) { "foo" }

          include_examples "unknown job action name"
        end

        context "when the first argument is a Hash object not containing a job payload" do
          let(:first_argument) { { "foo" => "bar" } }

          include_examples "unknown job action name"

          context "when the argument contains an invalid job_class value" do
            let(:first_argument) { { "job_class" => :foo } }

            include_examples "unknown job action name"
          end
        end

        context "when the first argument is a Hash object containing a job payload" do
          let(:first_argument) do
            {
              "job_class" => "ActiveMailerTestJob",
              "job_id" => "23e79d48-6966-40d0-b2d4-f7938463a263",
              "queue_name" => "default",
              "arguments" => [
                "foo", { "foo" => "Foo", "bar" => "Bar", "baz" => { 1 => :bar } }
              ]
            }
          end

          it "sets the action name to the job class in the first argument" do
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "action" => "ActiveMailerTestJob#perform"
            )
          end

          it "stores the job metadata on the transaction" do
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "id" => kind_of(String),
              "error" => nil,
              "namespace" => namespace,
              "metadata" => {
                "queue" => "default"
              },
              "sample_data" => {
                "environment" => {},
                "params" => [
                  "foo",
                  {
                    "foo" => "Foo",
                    "bar" => "Bar",
                    "baz" => { "1" => "bar" }
                  }
                ],
                "tags" => {}
              }
            )
          end

          it "does not log a debug message" do
            expect(log_contents(log)).to_not contains_log(
              :debug, "Unable to determine an action name from Sidekiq payload"
            )
          end
        end
      end
    end
  end

  shared_examples "unknown job action name" do
    it "sets the action name to unknown" do
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include("action" => "unknown")
    end

    it "stores no sample data" do
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "sample_data" => {
          "environment" => {},
          "params" => [],
          "tags" => {}
        }
      )
    end

    it "logs a debug message" do
      expect(log_contents(log)).to contains_log(
        :debug, "Unable to determine an action name from Sidekiq payload: #{item}"
      )
    end
  end

  context "with an error" do
    let(:error) { ExampleException }

    it "creates a transaction and adds the error" do
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, :queue => "default", :status => :failed)
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, :queue => "default", :status => :processed)

      expect do
        perform_job { raise error, "uh oh" }
      end.to raise_error(error)

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "id" => kind_of(String),
        "action" => "TestClass#perform",
        "error" => {
          "name" => "ExampleException",
          "message" => "uh oh",
          # TODO: backtrace should be an Array of Strings
          # https://github.com/appsignal/appsignal-agent/issues/294
          "backtrace" => kind_of(String)
        },
        "metadata" => {
          "extra" => "data",
          "queue" => "default",
          "retry_count" => "0"
        },
        "namespace" => namespace,
        "sample_data" => {
          "environment" => {},
          "params" => expected_args,
          "tags" => {}
        }
      )
      expect_transaction_to_have_sidekiq_event(transaction_hash)
    end

    include_examples "sidekiq metadata"
  end

  context "without an error" do
    it "creates a transaction with events" do
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, :queue => "default", :status => :processed)

      perform_job

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "id" => kind_of(String),
        "action" => "TestClass#perform",
        "error" => nil,
        "metadata" => {
          "extra" => "data",
          "queue" => "default",
          "retry_count" => "0"
        },
        "namespace" => namespace,
        "sample_data" => {
          "environment" => {},
          "params" => expected_args,
          "tags" => {}
        }
      )
      # TODO: Not available in transaction.to_h yet.
      # https://github.com/appsignal/appsignal-agent/issues/293
      expect(transaction.request.env).to eq(
        :queue_start => Time.parse("2001-01-01 10:00:00UTC").to_f
      )
      expect_transaction_to_have_sidekiq_event(transaction_hash)
    end

    include_examples "sidekiq metadata"
  end

  def perform_job
    Timecop.freeze(Time.parse("2001-01-01 10:01:00UTC")) do
      plugin.call(worker, item, queue) do
        yield if block_given?
      end
    end
  end

  def transaction
    test_store[:transaction]
  end

  def expect_transaction_to_have_sidekiq_event(transaction_hash)
    events = transaction_hash["events"]
    expect(events.count).to eq(1)
    expect(events.first).to include(
      "name"        => "perform_job.sidekiq",
      "title"       => "",
      "count"       => 1,
      "body"        => "",
      "body_format" => Appsignal::EventFormatter::DEFAULT
    )
  end
end

describe Appsignal::Hooks::SidekiqHook do
  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    context "when Sidekiq constant is found" do
      before { Object.const_set("Sidekiq", 1) }
      after { Object.send(:remove_const, "Sidekiq") }

      it { is_expected.to be_truthy }
    end

    context "when Sidekiq constant is not found" do
      before { Object.send(:remove_const, "Sidekiq") if defined?(Sidekiq) }

      it { is_expected.to be_falsy }
    end
  end

  describe "#install" do
    before do
      Appsignal.config = project_fixture_config
      class Sidekiq
        def self.middlewares
          @middlewares ||= Set.new
        end

        def self.configure_server
          yield self
        end

        def self.server_middleware
          yield middlewares
        end
      end
    end
    after { Object.send(:remove_const, "Sidekiq") }

    it "adds the AppSignal SidekiqPlugin to the Sidekiq middleware chain" do
      described_class.new.install

      expect(Sidekiq.middlewares).to include(Appsignal::Hooks::SidekiqPlugin)
    end
  end
end

describe Appsignal::Hooks::SidekiqProbe do
  describe "#call" do
    let(:probe) { described_class.new }
    let(:redis_hostname) { "localhost" }
    let(:expected_default_tags) { { :hostname => "localhost" } }
    before do
      Appsignal.config = project_fixture_config
      class Sidekiq
        def self.redis_info
          {
            "connected_clients" => 2,
            "used_memory" => 1024,
            "used_memory_rss" => 512
          }
        end

        def self.redis
          yield Client.new
        end

        class Client
          def connection
            { :host => "localhost" }
          end
        end

        class Stats
          class << self
            attr_reader :calls

            def count_call
              @calls ||= -1
              @calls += 1
            end
          end

          def workers_size
            # First method called, so count it towards a call
            self.class.count_call
            24
          end

          def processes_size
            25
          end

          # Return two different values for two separate calls.
          # This allows us to test the delta of the value send as a gauge.
          def processed
            [10, 15][self.class.calls]
          end

          # Return two different values for two separate calls.
          # This allows us to test the delta of the value send as a gauge.
          def failed
            [10, 13][self.class.calls]
          end

          def retry_size
            12
          end

          # Return two different values for two separate calls.
          # This allows us to test the delta of the value send as a gauge.
          def dead_size
            [10, 12][self.class.calls]
          end

          def scheduled_size
            14
          end

          def enqueued
            15
          end
        end

        class Queue
          Queue = Struct.new(:name, :size, :latency)

          def self.all
            [
              Queue.new("default", 10, 12),
              Queue.new("critical", 1, 2)
            ]
          end
        end
      end
    end
    after { Object.send(:remove_const, "Sidekiq") }

    it "loads Sidekiq::API" do
      expect(defined?(Sidekiq::API)).to be_falsy
      probe
      expect(defined?(Sidekiq::API)).to be_truthy
    end

    it "collects custom metrics" do
      expect_gauge("worker_count", 24).twice
      expect_gauge("process_count", 25).twice
      expect_gauge("connection_count", 2).twice
      expect_gauge("memory_usage", 1024).twice
      expect_gauge("memory_usage_rss", 512).twice
      expect_gauge("job_count", 5, :status => :processed) # Gauge delta
      expect_gauge("job_count", 3, :status => :failed) # Gauge delta
      expect_gauge("job_count", 12, :status => :retry_queue).twice
      expect_gauge("job_count", 2, :status => :died) # Gauge delta
      expect_gauge("job_count", 14, :status => :scheduled).twice
      expect_gauge("job_count", 15, :status => :enqueued).twice
      expect_gauge("queue_length", 10, :queue => "default").twice
      expect_gauge("queue_latency", 12, :queue => "default").twice
      expect_gauge("queue_length", 1, :queue => "critical").twice
      expect_gauge("queue_latency", 2, :queue => "critical").twice
      # Call probe twice so we can calculate the delta for some gauge values
      probe.call
      probe.call
    end

    context "when hostname is configured for probe" do
      let(:redis_hostname) { "my_redis_server" }
      let(:probe) { described_class.new(:hostname => redis_hostname) }

      it "uses the redis hostname for the hostname tag" do
        allow(Appsignal).to receive(:set_gauge).and_call_original
        probe.call
        expect(Appsignal).to have_received(:set_gauge)
          .with(anything, anything, :hostname => redis_hostname).at_least(:once)
      end
    end

    def expect_gauge(key, value, tags = {})
      expect(Appsignal).to receive(:set_gauge)
        .with("sidekiq_#{key}", value, expected_default_tags.merge(tags))
        .and_call_original
    end
  end
end
