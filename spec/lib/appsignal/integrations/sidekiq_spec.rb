require "appsignal/integrations/sidekiq"

describe Appsignal::Integrations::SidekiqDeathHandler do
  before { start_agent }
  around { |example| keep_transactions { example.run } }

  let(:exception) do
    raise ExampleStandardError, "uh oh"
  rescue => error
    error
  end
  let(:job_context) { {} }
  let(:transaction) { http_request_transaction }
  before { set_current_transaction(transaction) }

  def call_handler
    expect do
      described_class.new.call(job_context, exception)
    end.to_not(change { created_transactions.count })
  end

  def expect_error_on_transaction
    expect(last_transaction).to have_error("ExampleStandardError", "uh oh")
  end

  def expect_no_error_on_transaction
    expect(last_transaction).to_not have_error
  end

  context "when sidekiq_report_errors = none" do
    before do
      Appsignal.config[:sidekiq_report_errors] = "none"
      call_handler
    end

    it "doesn't track the error on the transaction" do
      expect_no_error_on_transaction
    end
  end

  context "when sidekiq_report_errors = all" do
    before do
      Appsignal.config[:sidekiq_report_errors] = "all"
      call_handler
    end

    it "doesn't track the error on the transaction" do
      expect_no_error_on_transaction
    end
  end

  context "when sidekiq_report_errors = discard" do
    before do
      Appsignal.config[:sidekiq_report_errors] = "discard"
      call_handler
    end

    it "records each occurrence of the error on the transaction" do
      expect_error_on_transaction
    end
  end
end

describe Appsignal::Integrations::SidekiqErrorHandler do
  before { start_agent }
  around { |example| keep_transactions { example.run } }

  let(:exception) do
    raise ExampleStandardError, "uh oh"
  rescue => error
    error
  end

  context "when error is an internal error" do
    let(:job_context) do
      {
        :context => "Sidekiq internal error!",
        :jobstr => "{ bad json }"
      }
    end

    def expect_report_internal_error
      expect do
        described_class.new.call(exception, job_context)
      end.to(change { created_transactions.count }.by(1))

      transaction = last_transaction
      expect(transaction).to have_action("SidekiqInternal")
      expect(transaction).to have_error("ExampleStandardError", "uh oh")
      expect(transaction).to include_params(
        "jobstr" => "{ bad json }"
      )
      expect(transaction).to include_metadata(
        "sidekiq_error" => "Sidekiq internal error!"
      )
    end

    context "when sidekiq_report_errors = none" do
      before { Appsignal.config[:sidekiq_report_errors] = "none" }

      it "tracks the error on a new transaction" do
        expect_report_internal_error
      end
    end

    context "when sidekiq_report_errors = all" do
      before { Appsignal.config[:sidekiq_report_errors] = "all" }

      it "tracks the error on a new transaction" do
        expect_report_internal_error
      end
    end

    context "when sidekiq_report_errors = discard" do
      before { Appsignal.config[:sidekiq_report_errors] = "discard" }

      it "tracks the error on a new transaction" do
        expect_report_internal_error
      end
    end
  end

  context "when error is a job error" do
    let(:sidekiq_context) { { :job => {} } }
    let(:transaction) { http_request_transaction }
    before do
      transaction.set_action("existing transaction action")
      set_current_transaction(transaction)
    end

    def call_handler
      expect do
        described_class.new.call(exception, sidekiq_context)
      end.to_not(change { created_transactions.count })
    end

    def expect_error_on_transaction
      expect(last_transaction).to have_error("ExampleStandardError", "uh oh")
    end

    def expect_no_error_on_transaction
      expect(last_transaction).to_not have_error
    end

    context "when sidekiq_report_errors = none" do
      before do
        Appsignal.config[:sidekiq_report_errors] = "none"
        call_handler
      end

      it "doesn't track the error on the transaction" do
        expect_no_error_on_transaction
        expect(last_transaction).to be_completed
      end
    end

    context "when sidekiq_report_errors = all" do
      before do
        Appsignal.config[:sidekiq_report_errors] = "all"
        call_handler
      end

      it "records each occurrence of the error on the transaction" do
        expect_error_on_transaction
        expect(last_transaction).to be_completed
      end
    end

    context "when sidekiq_report_errors = discard" do
      before do
        Appsignal.config[:sidekiq_report_errors] = "discard"
        call_handler
      end

      it "doesn't track the error on the transaction" do
        expect_no_error_on_transaction
        expect(last_transaction).to be_completed
      end
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
    Appsignal.internal_logger = test_logger(log)
  end
  around { |example| keep_transactions { example.run } }
  after :with_yaml_parse_error => false do
    expect(log_contents(log)).to_not contains_log(:warn, "Unable to load YAML")
  end

  describe "internal Sidekiq job values" do
    it "does not save internal Sidekiq values as metadata on transaction" do
      perform_sidekiq_job

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
      perform_sidekiq_job

      expect(transaction).to include_params(
        [
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
      perform_sidekiq_job

      expect(transaction).to include_params(expected_args << "[encrypted data]")
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
      perform_sidekiq_job

      expect(transaction).to have_action("DelayedTestClass.foo_method")
      expect(transaction).to include_params(["bar" => "baz"])
    end

    context "when job arguments is a malformed YAML object", :with_yaml_parse_error => true do
      before { item["args"] = [] }

      it "logs a warning and uses the default argument" do
        perform_sidekiq_job

        expect(transaction).to have_action("Sidekiq::Extensions::DelayedClass#perform")
        expect(transaction).to include_params([])
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
      perform_sidekiq_job

      expect(transaction).to have_action("DelayedTestClass#foo_method")
      expect(transaction).to include_params(["bar" => "baz"])
    end

    context "when job arguments is a malformed YAML object", :with_yaml_parse_error => true do
      before { item["args"] = [] }

      it "logs a warning and uses the default argument" do
        perform_sidekiq_job

        expect(transaction).to have_action("Sidekiq::Extensions::DelayedModel#perform")
        expect(transaction).to include_params([])
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
        perform_sidekiq_job { raise error, "uh oh" }
      end.to raise_error(error)

      expect(transaction).to have_id(jid)
      expect(transaction).to have_namespace(namespace)
      expect(transaction).to have_action("TestClass#perform")
      expect(transaction).to have_error("ExampleException", "uh oh")
      expect(transaction).to include_metadata(
        "extra" => "data",
        "queue" => "default",
        "retry_count" => "0"
      )
      expect(transaction).to_not include_environment
      expect(transaction).to include_params(expected_args)
      expect(transaction).to_not include_tags
      expect(transaction).to_not include_breadcrumbs
      expect_transaction_to_have_sidekiq_event(transaction)
    end
  end

  if DependencyHelper.rails7_present?
    context "with Rails error reporter" do
      include RailsHelper

      it "reports the worker name as the action, copies the namespace and tags" do
        Appsignal.config = project_fixture_config("production")
        with_rails_error_reporter do
          perform_sidekiq_job do
            Appsignal.tag_job("test_tag" => "value")
            Rails.error.handle do
              raise ExampleStandardError, "uh oh"
            end
          end
        end

        expect(created_transactions.count).to eq(2)
        tags = { "test_tag" => "value" }
        sidekiq_transaction = created_transactions.first
        error_reporter_transaction = created_transactions.last

        expect(sidekiq_transaction).to have_namespace("background_job")
        expect(sidekiq_transaction).to have_action("TestClass#perform")
        expect(sidekiq_transaction).to include_tags(tags)

        expect(error_reporter_transaction).to have_namespace("background_job")
        expect(error_reporter_transaction).to have_action("TestClass#perform")
        expect(error_reporter_transaction).to include_tags(tags)
      end
    end
  end

  context "without an error" do
    it "creates a transaction with events" do
      # TODO: additional curly brackets required for issue
      # https://github.com/rspec/rspec-mocks/issues/1460
      expect(Appsignal).to receive(:increment_counter)
        .with("sidekiq_queue_job_count", 1, { :queue => "default", :status => :processed })
      perform_sidekiq_job

      expect(transaction).to have_id(jid)
      expect(transaction).to have_namespace(namespace)
      expect(transaction).to have_action("TestClass#perform")
      expect(transaction).to_not have_error
      expect(transaction).to_not include_tags
      expect(transaction).to_not include_environment
      expect(transaction).to_not include_breadcrumbs
      expect(transaction).to_not include_params(expected_args)
      expect(transaction).to include_metadata(
        "extra" => "data",
        "queue" => "default",
        "retry_count" => "0"
      )
      expect(transaction).to have_queue_start(Time.parse("2001-01-01 10:00:00UTC").to_i * 1000)
      expect_transaction_to_have_sidekiq_event(transaction)
    end
  end

  def perform_sidekiq_job
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

  def expect_transaction_to_have_sidekiq_event(transaction)
    expect(transaction.to_h["events"].count).to eq(1)
    expect(transaction).to include_event(
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
    include RailsHelper
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
      { "executions" => 1 }.tap do |hash|
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
    around do |example|
      start_agent
      Appsignal.internal_logger = test_logger(log)
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
      with_rails_error_reporter do
        keep_transactions do
          Sidekiq::Testing.fake! do
            example.run
          end
        end
      end
    end
    after do
      Object.send(:remove_const, :ActiveJobSidekiqTestJob)
      Object.send(:remove_const, :ActiveJobSidekiqErrorTestJob)
    end

    it "reports the transaction from the ActiveJob integration" do
      perform_sidekiq_job(ActiveJobSidekiqTestJob, given_args)

      transaction = last_transaction
      expect(transaction).to have_namespace(namespace)
      expect(transaction).to have_action("ActiveJobSidekiqTestJob#perform")
      expect(transaction).to_not have_error
      expect(transaction).to include_metadata("queue" => "default")
      expect(transaction).to_not include_environment
      expect(transaction).to include_params([expected_args])
      expect(transaction).to include_tags(expected_tags.merge("queue" => "default"))
      expect(transaction).to have_queue_start(time.to_i * 1000)

      events = transaction.to_h["events"]
        .sort_by { |e| e["start"] }
        .map { |event| event["name"] }
      expect(events).to eq(expected_perform_events)
    end

    context "with error" do
      it "reports the error on the transaction from the ActiveRecord integration" do
        expect do
          perform_sidekiq_job(ActiveJobSidekiqErrorTestJob, given_args)
        end.to raise_error(RuntimeError, "uh oh")

        transaction = last_transaction
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ActiveJobSidekiqErrorTestJob#perform")
        expect(transaction).to have_error("RuntimeError", "uh oh")
        expect(transaction).to include_metadata("queue" => "default")
        expect(transaction).to_not include_environment
        expect(transaction).to include_params([expected_args])
        expect(transaction).to include_tags(expected_tags.merge("queue" => "default"))
        expect(transaction).to have_queue_start(time.to_i * 1000)

        events = transaction.to_h["events"]
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
        expect(transaction).to have_action("ActionMailerSidekiqTestJob#welcome")
        expect(transaction).to include_params(
          ["ActionMailerSidekiqTestJob", "welcome",
           "deliver_now"] + expected_wrapped_args
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

    def perform_sidekiq_job(job_class, args)
      perform_sidekiq { job_class.perform_later(args) }
    end

    def perform_mailer(mailer, method, args = nil)
      perform_sidekiq { perform_action_mailer(mailer, method, args) }
    end
  end
end
