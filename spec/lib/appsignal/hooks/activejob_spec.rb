if DependencyHelper.active_job_present?
  require "active_job"
  require "action_mailer"

  describe Appsignal::Hooks::ActiveJobHook do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      context "when ActiveJob constant is found" do
        before { stub_const "ActiveJob", Class.new }

        it { is_expected.to be_truthy }
      end

      context "when ActiveJob constant is not found" do
        before { hide_const "ActiveJob" }

        it { is_expected.to be_falsy }
      end
    end

    describe "#install" do
      it "extends ActiveJob::Base with the AppSignal ActiveJob plugin" do
        described_class.new.install

        path, _line_number = ActiveJob::Base.method(:execute).source_location
        expect(path).to end_with("/lib/appsignal/hooks/active_job.rb")
      end
    end
  end

  describe Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation do
    let(:time) { Time.parse("2001-01-01 10:00:00UTC") }
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
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
    before do
      ActiveJob::Base.queue_adapter = :inline

      start_agent
      Appsignal.logger = test_logger(log)
      class ActiveJobTestJob < ActiveJob::Base
        def perform(*_args)
        end
      end

      class ActiveJobErrorTestJob < ActiveJob::Base
        def perform(*_args)
          raise "uh oh"
        end
      end
    end
    around { |example| keep_transactions { example.run } }
    after do
      Object.send(:remove_const, :ActiveJobTestJob)
      Object.send(:remove_const, :ActiveJobErrorTestJob)
    end

    it "reports the name from the ActiveJob integration" do
      perform_job(ActiveJobTestJob, given_args)

      transaction = last_transaction
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "action" => "ActiveJobTestJob#perform",
        "error" => nil,
        "namespace" => namespace,
        "metadata" => {},
        "sample_data" => hash_including(
          "params" => [expected_args],
          "tags" => {
            "queue" => "default"
          }
        )
      )
      events = transaction_hash["events"]
        .sort_by { |e| e["start"] }
        .map { |event| event["name"] }
      expect(events).to eq(["perform_start.active_job", "perform.active_job"])
    end

    context "with error" do
      it "reports the error on the transaction from the ActiveRecord integration" do
        expect do
          perform_job(ActiveJobErrorTestJob, given_args)
        end.to raise_error(RuntimeError, "uh oh")

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "action" => "ActiveJobErrorTestJob#perform",
          "error" => {
            "name" => "RuntimeError",
            "message" => "uh oh",
            "backtrace" => kind_of(String)
          },
          "namespace" => namespace,
          "metadata" => {},
          "sample_data" => hash_including(
            "params" => [expected_args],
            "tags" => {
              "queue" => "default"
            }
          )
        )
        events = transaction_hash["events"]
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }
        expect(events).to eq(["perform_start.active_job", "perform.active_job"])
      end
    end

    context "when wrapped in another transaction" do
      it "does not create a new transaction or close the currently open one" do
        current_transaction = background_job_transaction
        allow(current_transaction).to receive(:complete).and_call_original
        set_current_transaction current_transaction

        perform_job(ActiveJobTestJob, given_args)

        expect(created_transactions.count).to eql(1)
        expect(current_transaction).to_not have_received(:complete)
        current_transaction.complete

        transaction = current_transaction
        transaction_hash = transaction.to_h
        # It does set data on the transaction
        expect(transaction_hash).to include(
          "id" => current_transaction.transaction_id,
          "action" => "ActiveJobTestJob#perform",
          "error" => nil,
          "namespace" => namespace,
          "metadata" => {},
          "sample_data" => hash_including(
            "params" => [expected_args],
            "tags" => {
              "queue" => "default"
            }
          )
        )
        events = transaction_hash["events"]
          .reject { |e| e["name"] == "enqueue.active_job" }
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }
        expect(events).to eq(["perform_start.active_job", "perform.active_job"])
      end
    end

    context "with filtered params" do
      it "filters the configured params" do
        Appsignal.config = project_fixture_config("production")
        Appsignal.config[:filter_parameters] = ["foo"]
        perform_job(ActiveJobTestJob, given_args)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash["sample_data"]["params"]).to include(
          [
            "foo",
            {
              "_aj_symbol_keys" => ["foo"],
              "foo" => "[FILTERED]",
              "bar" => "Bar",
              "baz" => { "_aj_symbol_keys" => [], "1" => "foo" }
            }
          ]
        )
      end
    end

    context "with provider_job_id", :skip => DependencyHelper.rails_version < Gem::Version.new("5.0.0") do
      before do
        module ActiveJob
          module QueueAdapters
            # Adapter used in our test suite to add provider data to the job
            # data, as is done by Rails provided ActiveJob adapters.
            #
            # This implementation is based on the
            # `ActiveJob::QueueAdapters::InlineAdapter`.
            class AppsignalTestAdapter < InlineAdapter
              def enqueue(job)
                Base.execute(job.serialize.merge("provider_job_id" => "my_provider_job_id"))
              end
            end
          end
        end

        class ProviderWrappedActiveJobTestJob < ActiveJob::Base
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end
      end
      after do
        ActiveJob::QueueAdapters.send(:remove_const, :AppsignalTestAdapter)
        Object.send(:remove_const, :ProviderWrappedActiveJobTestJob)
      end

      it "sets provider_job_id as tag" do
        perform_job(ProviderWrappedActiveJobTestJob, given_args)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash["sample_data"]["tags"]).to include(
          "provider_job_id" => "my_provider_job_id"
        )
      end
    end

    context "with ActionMailer job" do
      include ActionMailerHelpers

      before do
        class ActionMailerTestJob < ActionMailer::Base
          def welcome(*args)
          end
        end
      end
      after do
        Object.send(:remove_const, :ActionMailerTestJob)
      end

      context "without params" do
        it "sets the Action mailer data on the transaction" do
          perform_mailer(ActionMailerTestJob, :welcome)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "ActionMailerTestJob#welcome",
            "sample_data" => hash_including(
              "params" => ["ActionMailerTestJob", "welcome", "deliver_now"],
              "tags" => { "queue" => "mailers" }
            )
          )
        end
      end

      context "with params" do
        it "sets the Action mailer data on the transaction" do
          perform_mailer(ActionMailerTestJob, :welcome, given_args)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "ActionMailerTestJob#welcome",
            "sample_data" => hash_including(
              "params" => ["ActionMailerTestJob", "welcome", "deliver_now", expected_args],
              "tags" => { "queue" => "mailers" }
            )
          )
        end
      end
    end

    def perform_active_job
      Timecop.freeze(time) do
        yield
      end
    end

    def perform_job(job_class, args)
      perform_active_job { job_class.perform_later(args) }
    end

    def perform_mailer(mailer, method, args = nil)
      perform_active_job { perform_action_mailer(mailer, method, args) }
    end
  end
end
