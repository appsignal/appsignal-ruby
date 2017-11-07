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
    expect(Appsignal::Transaction).to receive(:clear_current_transaction!).at_least(:once) do
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
    end
  end

  context "with an error" do
    let(:error) { ExampleException }

    it "creates a transaction and adds the error" do
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
