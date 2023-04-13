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
        start_agent

        path, _line_number = ActiveJob::Base.method(:execute).source_location
        expect(path).to end_with("/lib/appsignal/hooks/active_job.rb")
      end
    end
  end

  describe Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation do
    include ActiveJobHelpers
    let(:time) { Time.parse("2001-01-01 10:00:00UTC") }
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:queue) { "default" }
    let(:log) { StringIO.new }
    let(:parameterized_given_args) do
      {
        :foo => "Foo",
        "bar" => "Bar",
        "baz" => { "1" => "foo" }
      }
    end
    let(:method_given_args) do
      [
        "foo",
        parameterized_given_args
      ]
    end
    let(:parameterized_expected_args) do
      {
        "_aj_symbol_keys" => ["foo"],
        "foo" => "Foo",
        "bar" => "Bar",
        "baz" => {
          "_aj_symbol_keys" => [],
          "1" => "foo"
        }
      }
    end
    let(:method_expected_args) do
      [
        "foo",
        parameterized_expected_args
      ]
    end
    let(:expected_perform_events) do
      if DependencyHelper.rails7_present?
        ["perform.active_job", "perform_start.active_job"]
      else
        ["perform_start.active_job", "perform.active_job"]
      end
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
        def perform
          raise "uh oh"
        end
      end

      class ActiveJobCustomQueueTestJob < ActiveJob::Base
        queue_as :custom_queue

        def perform(*_args)
        end
      end
    end
    around { |example| keep_transactions { example.run } }
    after do
      Object.send(:remove_const, :ActiveJobTestJob)
      Object.send(:remove_const, :ActiveJobErrorTestJob)
      Object.send(:remove_const, :ActiveJobCustomQueueTestJob)
    end

    it "reports the name from the ActiveJob integration" do
      tags = { :queue => queue }
      expect(Appsignal).to receive(:increment_counter)
        .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))

      perform_job(ActiveJobTestJob)

      transaction = last_transaction
      transaction_hash = transaction.to_h
      expect(transaction_hash).to include(
        "action" => "ActiveJobTestJob#perform",
        "error" => nil,
        "namespace" => namespace,
        "metadata" => {},
        "sample_data" => hash_including(
          "params" => [],
          "tags" => {
            "active_job_id" => kind_of(String),
            "queue" => queue
          }
        )
      )
      events = transaction_hash["events"]
        .sort_by { |e| e["start"] }
        .map { |event| event["name"] }

      expect(events).to eq(expected_perform_events)
    end

    context "with custom queue" do
      it "reports the custom queue as tag on the transaction" do
        tags = { :queue => "custom_queue" }
        expect(Appsignal).to receive(:increment_counter)
          .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))
        perform_job(ActiveJobCustomQueueTestJob)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "sample_data" => hash_including(
            "tags" => hash_including("queue" => "custom_queue")
          )
        )
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
      context "with priority" do
        before do
          class ActiveJobPriorityTestJob < ActiveJob::Base
            queue_with_priority 10

            def perform(*_args)
            end
          end
        end
        after do
          Object.send(:remove_const, :ActiveJobPriorityTestJob)
        end

        it "reports the priority as tag on the transaction" do
          tags = { :queue => queue }
          expect(Appsignal).to receive(:increment_counter)
            .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))
          expect(Appsignal).to receive(:increment_counter)
            .with("active_job_queue_priority_job_count", 1, tags.merge(:priority => 10,
              :status => :processed))

          perform_job(ActiveJobPriorityTestJob)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "sample_data" => hash_including(
              "tags" => hash_including("queue" => queue, "priority" => 10)
            )
          )
        end
      end
    end

    context "with error" do
      it "reports the error on the transaction from the ActiveRecord integration" do
        allow(Appsignal).to receive(:increment_counter) # Other calls we're testing in another test
        tags = { :queue => queue }
        expect(Appsignal).to receive(:increment_counter)
          .with("active_job_queue_job_count", 1, tags.merge(:status => :failed))
        expect(Appsignal).to receive(:increment_counter)
          .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))

        expect do
          perform_job(ActiveJobErrorTestJob)
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
            "params" => [],
            "tags" => {
              "active_job_id" => kind_of(String),
              "queue" => queue
            }
          )
        )
        events = transaction_hash["events"]
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }

        expect(events).to eq(expected_perform_events)
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
        context "with priority" do
          before do
            class ActiveJobErrorPriorityTestJob < ActiveJob::Base
              queue_with_priority 10

              def perform(*_args)
                raise "uh oh"
              end
            end
          end
          after do
            Object.send(:remove_const, :ActiveJobErrorPriorityTestJob)
          end

          it "reports the priority as tag on the transaction" do
            tags = { :queue => queue }
            expect(Appsignal).to receive(:increment_counter)
              .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))
            expect(Appsignal).to receive(:increment_counter)
              .with("active_job_queue_job_count", 1, tags.merge(:status => :failed))
            expect(Appsignal).to receive(:increment_counter)
              .with("active_job_queue_priority_job_count", 1, tags.merge(:priority => 10,
                :status => :processed))
            expect(Appsignal).to receive(:increment_counter)
              .with("active_job_queue_priority_job_count", 1, tags.merge(:priority => 10,
                :status => :failed))

            expect do
              perform_job(ActiveJobErrorPriorityTestJob)
            end.to raise_error(RuntimeError, "uh oh")

            transaction = last_transaction
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "sample_data" => hash_including(
                "tags" => hash_including("queue" => queue, "priority" => 10)
              )
            )
          end
        end
      end
    end

    context "when wrapped in another transaction" do
      it "does not create a new transaction or close the currently open one" do
        current_transaction = background_job_transaction
        allow(current_transaction).to receive(:complete).and_call_original
        set_current_transaction current_transaction

        perform_job(ActiveJobTestJob)

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
            "params" => [],
            "tags" => {
              "active_job_id" => kind_of(String),
              "queue" => queue
            }
          )
        )
        events = transaction_hash["events"]
          .reject { |e| e["name"] == "enqueue.active_job" }
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }

        expect(events).to eq(expected_perform_events)
      end
    end

    context "with params" do
      it "filters the configured params" do
        Appsignal.config = project_fixture_config("production")
        Appsignal.config[:filter_parameters] = ["foo"]
        perform_job(ActiveJobTestJob, method_given_args)

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

    context "with provider_job_id",
      :skip => DependencyHelper.rails_version < Gem::Version.new("5.0.0") do
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
        perform_job(ProviderWrappedActiveJobTestJob)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash["sample_data"]["tags"]).to include(
          "provider_job_id" => "my_provider_job_id"
        )
      end
    end

    context "with enqueued_at",
      :skip => DependencyHelper.rails_version < Gem::Version.new("6.0.0") do
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
                Base.execute(job.serialize.merge("enqueued_at" => "2020-10-10T10:10:10Z"))
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

      it "sets queue time on transaction" do
        allow_any_instance_of(Appsignal::Transaction).to receive(:set_queue_start).and_call_original
        perform_job(ProviderWrappedActiveJobTestJob)

        transaction = last_transaction
        queue_time = Time.parse("2020-10-10T10:10:10Z")
        expect(transaction).to have_received(:set_queue_start)
          .with((queue_time.to_f * 1_000).to_i)
      end
    end

    context "with ActionMailer job" do
      include ActionMailerHelpers

      before do
        class ActionMailerTestJob < ActionMailer::Base
          def welcome(_first_arg = nil, _second_arg = nil)
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
              "params" => ["ActionMailerTestJob", "welcome",
                           "deliver_now"] + active_job_args_wrapper,
              "tags" => {
                "active_job_id" => kind_of(String),
                "queue" => "mailers"
              }
            )
          )
        end
      end

      context "with multiple arguments" do
        it "sets the arguments on the transaction" do
          perform_mailer(ActionMailerTestJob, :welcome, method_given_args)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "ActionMailerTestJob#welcome",
            "sample_data" => hash_including(
              "params" => ["ActionMailerTestJob", "welcome",
                           "deliver_now"] + active_job_args_wrapper(:args => method_expected_args),
              "tags" => {
                "active_job_id" => kind_of(String),
                "queue" => "mailers"
              }
            )
          )
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.2.0")
        context "with parameterized arguments" do
          it "sets the arguments on the transaction" do
            perform_mailer(ActionMailerTestJob, :welcome, parameterized_given_args)

            transaction = last_transaction
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "action" => "ActionMailerTestJob#welcome",
              "sample_data" => hash_including(
                "params" => [
                  "ActionMailerTestJob",
                  "welcome",
                  "deliver_now"
                ] + active_job_args_wrapper(:params => parameterized_expected_args),
                "tags" => {
                  "active_job_id" => kind_of(String),
                  "queue" => "mailers"
                }
              )
            )
          end
        end
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("6.0.0")
      context "with ActionMailer MailDeliveryJob job" do
        include ActionMailerHelpers

        before do
          class ActionMailerTestMailDeliveryJob < ActionMailer::Base
            self.delivery_job = ActionMailer::MailDeliveryJob

            def welcome(*_args)
            end
          end
        end
        after do
          Object.send(:remove_const, :ActionMailerTestMailDeliveryJob)
        end

        it "sets the Action mailer data on the transaction" do
          perform_mailer(ActionMailerTestMailDeliveryJob, :welcome)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "ActionMailerTestMailDeliveryJob#welcome",
            "sample_data" => hash_including(
              "params" => [
                "ActionMailerTestMailDeliveryJob",
                "welcome",
                "deliver_now",
                { active_job_internal_key => ["args"], "args" => [] }
              ],
              "tags" => {
                "active_job_id" => kind_of(String),
                "queue" => "mailers"
              }
            )
          )
        end

        context "with method arguments" do
          it "sets the Action mailer data on the transaction" do
            perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, method_given_args)

            transaction = last_transaction
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "action" => "ActionMailerTestMailDeliveryJob#welcome",
              "sample_data" => hash_including(
                "params" => [
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["args"],
                    "args" => method_expected_args
                  }
                ],
                "tags" => {
                  "active_job_id" => kind_of(String),
                  "queue" => "mailers"
                }
              )
            )
          end
        end

        context "with parameterized arguments" do
          it "sets the Action mailer data on the transaction" do
            perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, parameterized_given_args)

            transaction = last_transaction
            transaction_hash = transaction.to_h
            expect(transaction_hash).to include(
              "action" => "ActionMailerTestMailDeliveryJob#welcome",
              "sample_data" => hash_including(
                "params" => [
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["params", "args"],
                    "args" => [],
                    "params" => parameterized_expected_args
                  }
                ],
                "tags" => {
                  "active_job_id" => kind_of(String),
                  "queue" => "mailers"
                }
              )
            )
          end
        end
      end
    end

    def perform_active_job(&block)
      Timecop.freeze(time, &block)
    end

    def perform_job(job_class, args = nil)
      perform_active_job do
        if args
          job_class.perform_later(args)
        else
          job_class.perform_later
        end
      end
    end

    def perform_mailer(mailer, method, args = nil)
      perform_active_job { perform_action_mailer(mailer, method, args) }
    end

    def active_job_internal_key
      if DependencyHelper.ruby_version >= Gem::Version.new("2.7.0")
        "_aj_ruby2_keywords"
      else
        "_aj_symbol_keys"
      end
    end
  end
end
