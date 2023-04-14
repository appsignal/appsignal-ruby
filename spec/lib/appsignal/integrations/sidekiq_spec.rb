require "appsignal/integrations/sidekiq"

describe Appsignal::Integrations::SidekiqErrorHandler do
  let(:log) { StringIO.new }
  before do
    start_agent
    Appsignal.logger = test_logger(log)
  end
  around { |example| keep_transactions { example.run } }

  context "without a current transction" do
    let(:exception) do
      raise ExampleStandardError, "uh oh"
    rescue => error
      error
    end
    let(:job_context) do
      {
        :context => "Sidekiq internal error!",
        :jobstr => "{ bad json }"
      }
    end

    it "tracks error on a new transaction" do
      described_class.new.call(exception, job_context)

      transaction_hash = last_transaction.to_h
      expect(transaction_hash["error"]).to include(
        "name" => "ExampleStandardError",
        "message" => "uh oh",
        "backtrace" => kind_of(String)
      )
      expect(transaction_hash["sample_data"]).to include(
        "params" => {
          "jobstr" => "{ bad json }"
        }
      )
      expect(transaction_hash["metadata"]).to include(
        "sidekiq_error" => "Sidekiq internal error!"
      )
    end
  end
end

describe Appsignal::Integrations::SidekiqMiddleware, :with_yaml_parse_error => false do
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
  let(:jid) { "b4a577edbccf1d805744efa9" }
  let(:item) do
    {
      "jid" => jid,
      "class" => job_class,
      "retry_count" => 0,
      "queue" => "default",
      "created_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
      "enqueued_at" => Time.parse("2001-01-01 10:00:00UTC").to_f,
      "args" => given_args,
      "extra" => "data"
    }
  end
  let(:plugin) { Appsignal::Integrations::SidekiqMiddleware.new }
  let(:log) { StringIO.new }
  before do
    start_agent
    Appsignal.logger = test_logger(log)
  end
  around { |example| keep_transactions { example.run } }
  after :with_yaml_parse_error => false do
    expect(log_contents(log)).to_not contains_log(:warn, "Unable to load YAML")
  end

  describe "internal Sidekiq job values" do
    it "does not save internal Sidekiq values as metadata on transaction" do
      perform_job

      transaction_hash = transaction.to_h
      expect(transaction_hash["metadata"].keys)
        .to_not include(*Appsignal::Integrations::SidekiqMiddleware::EXCLUDED_JOB_KEYS)
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
        "jid" => jid,
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
        "jid" => jid,
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

  context "with an error" do
    let(:error) { ExampleException }

    it "creates a transaction and adds the error" do
      # TODO: additional curly brackets required for issue
      # https://github.com/rspec/rspec-mocks/issues/1460
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, { :queue => "default", :status => :failed })
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, { :queue => "default", :status => :processed })
      expect do
        perform_job { raise error, "uh oh" }
      end.to raise_error(error)

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "id" => jid,
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
          "tags" => {},
          "breadcrumbs" => []
        }
      )
      expect_transaction_to_have_sidekiq_event(transaction_hash)
    end
  end

  if DependencyHelper.rails7_present?
    context "with Rails error reporter" do
      it "reports the worker name as the action, copies the namespace and tags" do
        Appsignal::Integrations::Railtie.initialize_appsignal(MyApp::Application.new)
        Appsignal.config = project_fixture_config("production")
        perform_job do
          Appsignal.tag_job("test_tag" => "value")
          Rails.error.handle do
            raise error, "uh oh"
          end
        end

        expect(created_transactions.count).to eq(2)
        expected_transaction = {
          "namespace" => "background_job",
          "action" => "TestClass#perform",
          "sample_data" => hash_including(
            "tags" => hash_including("test_tag" => "value")
          )
        }
        sidekiq_transaction = created_transactions.first.to_h
        error_reporter_transaction = created_transactions.last.to_h
        expect(sidekiq_transaction).to include(expected_transaction)
        expect(error_reporter_transaction).to include(expected_transaction)
      end
    end
  end

  context "without an error" do
    it "creates a transaction with events" do
      # TODO: additional curly brackets required for issue
      # https://github.com/rspec/rspec-mocks/issues/1460
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, { :queue => "default", :status => :processed })
      perform_job

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "id" => jid,
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
          "tags" => {},
          "breadcrumbs" => []
        }
      )
      # TODO: Not available in transaction.to_h yet.
      # https://github.com/appsignal/appsignal-agent/issues/293
      expect(transaction.request.env).to eq(
        :queue_start => Time.parse("2001-01-01 10:00:00UTC").to_f
      )
      expect_transaction_to_have_sidekiq_event(transaction_hash)
    end
  end

  def perform_job
    Timecop.freeze(Time.parse("2001-01-01 10:01:00UTC")) do
      exception = nil
      plugin.call(worker, item, queue) do
        yield if block_given?
      end
    rescue Exception => exception # rubocop:disable Lint/RescueException
      raise exception
    ensure
      Appsignal::Integrations::SidekiqErrorHandler.new.call(exception, :job => item) if exception
    end
  end

  def transaction
    last_transaction
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

if DependencyHelper.active_job_present?
  require "active_job"
  require "action_mailer"
  require "sidekiq/testing"

  describe "Sidekiq ActiveJob integration" do
    include ActiveJobHelpers
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:time) { Time.parse("2001-01-01 10:00:00UTC") }
    let(:log) { StringIO.new }
    let(:given_args) do
      [
        "foo",
        {
          :foo => "Foo",
          "bar" => "Bar",
          "baz" => { "1" => "foo" }
        }
      ]
    end
    let(:expected_args) do
      [
        "foo",
        {
          "_aj_symbol_keys" => ["foo"],
          "foo" => "Foo",
          "bar" => "Bar",
          "baz" => {
            "_aj_symbol_keys" => [],
            "1" => "foo"
          }
        }
      ]
    end
    let(:expected_wrapped_args) do
      if DependencyHelper.active_job_wraps_args?
        [{
          "_aj_ruby2_keywords" => ["args"],
          "args" => expected_args
        }]
      else
        expected_args
      end
    end
    let(:expected_tags) do
      {}.tap do |hash|
        hash["active_job_id"] = kind_of(String)
        if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
          hash["provider_job_id"] = kind_of(String)
        end
      end
    end
    let(:expected_perform_events) do
      if DependencyHelper.rails7_present?
        ["perform_job.sidekiq", "perform.active_job", "perform_start.active_job"]
      else
        ["perform_job.sidekiq", "perform_start.active_job", "perform.active_job"]
      end
    end
    before do
      start_agent
      Appsignal.logger = test_logger(log)
      ActiveJob::Base.queue_adapter = :sidekiq

      class ActiveJobSidekiqTestJob < ActiveJob::Base
        self.queue_adapter = :sidekiq

        def perform(*_args)
        end
      end

      class ActiveJobSidekiqErrorTestJob < ActiveJob::Base
        self.queue_adapter = :sidekiq

        def perform(*_args)
          raise "uh oh"
        end
      end
      # Manually add the AppSignal middleware for the Testing environment.
      # It doesn't use configured middlewares by default looks like.
      # We test somewhere else if the middleware is installed properly.
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Appsignal::Integrations::SidekiqMiddleware
      end
    end
    around do |example|
      keep_transactions do
        Sidekiq::Testing.fake! do
          example.run
        end
      end
    end
    after do
      Object.send(:remove_const, :ActiveJobSidekiqTestJob)
      Object.send(:remove_const, :ActiveJobSidekiqErrorTestJob)
    end

    it "reports the transaction from the ActiveJob integration" do
      perform_job(ActiveJobSidekiqTestJob, given_args)

      transaction = last_transaction
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "action" => "ActiveJobSidekiqTestJob#perform",
        "error" => nil,
        "namespace" => namespace,
        "metadata" => hash_including(
          "queue" => "default"
        ),
        "sample_data" => hash_including(
          "environment" => {},
          "params" => [expected_args],
          "tags" => expected_tags.merge("queue" => "default")
        )
      )
      expect(transaction.request.env).to eq(:queue_start => time.to_f)
      events = transaction_hash["events"]
        .sort_by { |e| e["start"] }
        .map { |event| event["name"] }

      expect(events).to eq(expected_perform_events)
    end

    context "with error" do
      it "reports the error on the transaction from the ActiveRecord integration" do
        expect do
          perform_job(ActiveJobSidekiqErrorTestJob, given_args)
        end.to raise_error(RuntimeError, "uh oh")

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "action" => "ActiveJobSidekiqErrorTestJob#perform",
          "error" => {
            "name" => "RuntimeError",
            "message" => "uh oh",
            "backtrace" => kind_of(String)
          },
          "namespace" => namespace,
          "metadata" => hash_including(
            "queue" => "default"
          ),
          "sample_data" => hash_including(
            "environment" => {},
            "params" => [expected_args],
            "tags" => expected_tags.merge("queue" => "default")
          )
        )
        expect(transaction.request.env).to eq(:queue_start => time.to_f)
        events = transaction_hash["events"]
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }

        expect(events).to eq(expected_perform_events)
      end
    end

    context "with ActionMailer" do
      include ActionMailerHelpers

      before do
        class ActionMailerSidekiqTestJob < ActionMailer::Base
          def welcome(*args)
          end
        end
      end

      it "reports ActionMailer data on the transaction" do
        perform_mailer(ActionMailerSidekiqTestJob, :welcome, given_args)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "action" => "ActionMailerSidekiqTestJob#welcome",
          "sample_data" => hash_including(
            "params" => ["ActionMailerSidekiqTestJob", "welcome",
                         "deliver_now"] + expected_wrapped_args
          )
        )
      end
    end

    def perform_sidekiq
      Timecop.freeze(time) do
        yield
        # Combined with Sidekiq::Testing.fake! and drain_all we get a
        # enqueue_at in the job data.
        Sidekiq::Worker.drain_all
      rescue Exception => exception # rubocop:disable Lint/RescueException
        raise exception
      ensure
        Appsignal::Integrations::SidekiqErrorHandler.new.call(exception, {}) if exception
      end
    end

    def perform_job(job_class, args)
      perform_sidekiq { job_class.perform_later(args) }
    end

    def perform_mailer(mailer, method, args = nil)
      perform_sidekiq { perform_action_mailer(mailer, method, args) }
    end
  end
end
