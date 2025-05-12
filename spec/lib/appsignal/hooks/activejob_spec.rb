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
    let(:options) { {} }
    before do
      ActiveJob::Base.queue_adapter = :inline

      start_agent(:options => options)
      stub_const("ActiveJobTestJob", Class.new(ActiveJob::Base) do
        def perform(*_args)
        end
      end)

      stub_const("ActiveJobErrorTestJob", Class.new(ActiveJob::Base) do
        def perform
          raise "uh oh"
        end
      end)

      stub_const("ActiveJobErrorWithRetryTestJob", Class.new(ActiveJob::Base) do
        retry_on StandardError, :wait => 0.seconds, :attempts => 2

        def perform
          raise "uh oh"
        end
      end)

      stub_const("ActiveJobCustomQueueTestJob", Class.new(ActiveJob::Base) do
        queue_as :custom_queue

        def perform(*_args)
        end
      end)
    end
    around { |example| keep_transactions { example.run } }

    it "reports the name from the ActiveJob integration" do
      tags = { :queue => queue }
      expect(Appsignal).to receive(:increment_counter)
        .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))

      queue_job(ActiveJobTestJob)

      transaction = last_transaction
      expect(transaction).to have_namespace(namespace)
      expect(transaction).to have_action("ActiveJobTestJob#perform")
      expect(transaction).to_not have_error
      expect(transaction).to_not include_metadata
      expect(transaction).to include_params([])
      expect(transaction).to include_tags(
        "active_job_id" => kind_of(String),
        "request_id" => kind_of(String),
        "queue" => queue,
        "executions" => 1
      )
      events = transaction.to_h["events"]
        .sort_by { |e| e["start"] }
        .map { |event| event["name"] }
      expect(events).to eq(expected_perform_events)
    end

    context "with custom queue" do
      it "reports the custom queue as tag on the transaction" do
        tags = { :queue => "custom_queue" }
        expect(Appsignal).to receive(:increment_counter)
          .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))
        queue_job(ActiveJobCustomQueueTestJob)

        expect(last_transaction).to include_tags("queue" => "custom_queue")
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
      context "with priority" do
        before do
          stub_const("ActiveJobPriorityTestJob", Class.new(ActiveJob::Base) do
            queue_with_priority 10

            def perform(*_args)
            end
          end)
        end

        it "reports the priority as tag on the transaction" do
          tags = { :queue => queue }
          expect(Appsignal).to receive(:increment_counter)
            .with("active_job_queue_job_count", 1, tags.merge(:status => :processed))
          expect(Appsignal).to receive(:increment_counter)
            .with("active_job_queue_priority_job_count", 1, tags.merge(:priority => 10,
              :status => :processed))

          queue_job(ActiveJobPriorityTestJob)

          expect(last_transaction).to include_tags("queue" => queue, "priority" => 10)
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
          queue_job(ActiveJobErrorTestJob)
        end.to raise_error(RuntimeError, "uh oh")

        transaction = last_transaction
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ActiveJobErrorTestJob#perform")
        expect(transaction).to have_error("RuntimeError", "uh oh")
        expect(transaction).to_not include_metadata
        expect(transaction).to include_params([])
        expect(transaction).to include_tags(
          "active_job_id" => kind_of(String),
          "request_id" => kind_of(String),
          "queue" => queue,
          "executions" => 1
        )

        events = transaction.to_h["events"]
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }
        expect(events).to eq(expected_perform_events)
      end

      context "with activejob_report_errors set to none" do
        let(:options) { { :activejob_report_errors => "none" } }

        it "does not report the error" do
          allow(Appsignal).to receive(:increment_counter)
          tags = { :queue => queue }
          expect(Appsignal).to receive(:increment_counter)
            .with("active_job_queue_job_count", 1, tags.merge(:status => :failed))

          expect do
            queue_job(ActiveJobErrorTestJob)
          end.to raise_error(RuntimeError, "uh oh")

          expect(last_transaction).to_not have_error
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("7.1.0")
        context "with activejob_report_errors set to discard" do
          let(:options) { { :activejob_report_errors => "discard" } }

          it "does not report error on first failure" do
            with_test_adapter do
              # Prevent the job from being instantly retried so we can test
              # what happens before it's retried
              allow_any_instance_of(ActiveJobErrorWithRetryTestJob).to receive(:retry_job)

              queue_job(ActiveJobErrorWithRetryTestJob)
            end

            transaction = last_transaction
            expect(transaction).to_not have_error
            expect(transaction).to include_tags("executions" => 1)
          end

          it "reports error when discarding the job" do
            allow(Appsignal).to receive(:increment_counter)
            tags = { :queue => queue }
            expect(Appsignal).to receive(:increment_counter)
              .with("active_job_queue_job_count", 1, tags.merge(:status => :failed))

            with_test_adapter do
              expect do
                queue_job(ActiveJobErrorWithRetryTestJob)
              end.to raise_error(RuntimeError, "uh oh")
            end

            transaction = last_transaction
            expect(transaction).to have_error("RuntimeError", "uh oh")
            expect(transaction).to include_tags("executions" => 2)
          end
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
        context "with priority" do
          before do
            stub_const("ActiveJobErrorPriorityTestJob", Class.new(ActiveJob::Base) do
              queue_with_priority 10

              def perform(*_args)
                raise "uh oh"
              end
            end)
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
              queue_job(ActiveJobErrorPriorityTestJob)
            end.to raise_error(RuntimeError, "uh oh")

            expect(last_transaction).to include_tags("queue" => queue, "priority" => 10)
          end
        end
      end
    end

    context "with retries" do
      it "reports the number of retries as executions" do
        with_test_adapter do
          expect do
            queue_job(ActiveJobErrorWithRetryTestJob)
          end.to raise_error(RuntimeError, "uh oh")
        end

        expect(last_transaction).to include_tags("executions" => 2)
      end
    end

    context "when wrapped in another transaction" do
      it "does not create a new transaction or close the currently open one" do
        current_transaction = background_job_transaction
        set_current_transaction current_transaction

        queue_job(ActiveJobTestJob)

        expect(created_transactions.count).to eql(1)

        transaction = current_transaction
        expect(transaction).to_not be_completed
        transaction._sample
        # It does set data on the transaction
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_id(current_transaction.transaction_id)
        expect(transaction).to have_action("ActiveJobTestJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_metadata
        expect(transaction).to include_params([])
        expect(transaction).to include_tags(
          "active_job_id" => kind_of(String),
          "request_id" => kind_of(String),
          "queue" => queue,
          "executions" => 1
        )

        events = transaction.to_h["events"]
          .reject { |e| e["name"] == "enqueue.active_job" }
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }
        expect(events).to eq(expected_perform_events)
      end
    end

    context "with params" do
      let(:options) { { :filter_parameters => ["foo"] } }

      it "filters the configured params" do
        queue_job(ActiveJobTestJob, method_given_args)

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
        stub_const(
          "ActiveJob::QueueAdapters::AppsignalTestAdapter",
          Class.new(ActiveJob::QueueAdapters::InlineAdapter) do
            # Adapter used in our test suite to add provider data to the job
            # data, as is done by Rails provided ActiveJob adapters.
            #
            # This implementation is based on the
            # `ActiveJob::QueueAdapters::InlineAdapter`.
            def enqueue(job)
              ActiveJob::Base.execute(
                job.serialize.merge("provider_job_id" => "my_provider_job_id")
              )
            end
          end
        )

        stub_const("ProviderWrappedActiveJobTestJob", Class.new(ActiveJob::Base) do
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end)
      end

      it "sets provider_job_id as tag" do
        queue_job(ProviderWrappedActiveJobTestJob)

        expect(last_transaction).to include_tags(
          "provider_job_id" => "my_provider_job_id"
        )
      end
    end

    context "with enqueued_at",
      :skip => DependencyHelper.rails_version < Gem::Version.new("6.0.0") do
      before do
        stub_const(
          "ActiveJob::QueueAdapters::AppsignalTestAdapter",
          Class.new(ActiveJob::QueueAdapters::InlineAdapter) do
            # Adapter used in our test suite to add provider data to the job
            # data, as is done by Rails provided ActiveJob adapters.
            #
            # This implementation is based on the
            # `ActiveJob::QueueAdapters::InlineAdapter`.
            def enqueue(job)
              ActiveJob::Base.execute(job.serialize.merge(
                # Is 1 hour before the `let(:time)` definition
                "enqueued_at" => "2001-01-01T09:00:00.000000000Z"
              ))
            end
          end
        )

        stub_const("ProviderWrappedActiveJobTestJob", Class.new(ActiveJob::Base) do
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end)
      end

      it "sets queue time on transaction" do
        queue_job(ProviderWrappedActiveJobTestJob)

        queue_time = Time.parse("2001-01-01T09:00:00.000000000Z")
        expect(last_transaction).to have_queue_start((queue_time.to_f * 1_000).to_i)
      end

      it "reports the queue time" do
        allow(Appsignal).to receive(:add_distribution_value)

        queue_job(ProviderWrappedActiveJobTestJob)

        # Asserts 1 hour queue time
        expect(Appsignal).to have_received(:add_distribution_value)
          .with("active_job_queue_time", 3_600_000.0, :queue => queue)
      end
    end

    context "with ActionMailer job" do
      include ActionMailerHelpers

      before do
        stub_const("ActionMailerTestJob", Class.new(ActionMailer::Base) do
          def welcome(_first_arg = nil, _second_arg = nil)
          end
        end)
      end

      context "without params" do
        it "sets the Action mailer data on the transaction" do
          perform_mailer(ActionMailerTestJob, :welcome)

          transaction = last_transaction
          expect(transaction).to have_action("ActionMailerTestJob#welcome")
          expect(transaction).to include_params(
            ["ActionMailerTestJob", "welcome", "deliver_now"] + active_job_args_wrapper
          )
          expect(transaction).to include_tags(
            "active_job_id" => kind_of(String),
            "request_id" => kind_of(String),
            "queue" => "mailers",
            "executions" => 1
          )
        end
      end

      context "with multiple arguments" do
        it "sets the arguments on the transaction" do
          perform_mailer(ActionMailerTestJob, :welcome, method_given_args)

          transaction = last_transaction
          expect(transaction).to have_action("ActionMailerTestJob#welcome")
          expect(transaction).to include_params(
            ["ActionMailerTestJob", "welcome",
             "deliver_now"] + active_job_args_wrapper(:args => method_expected_args)
          )
          expect(transaction).to include_tags(
            "active_job_id" => kind_of(String),
            "request_id" => kind_of(String),
            "queue" => "mailers",
            "executions" => 1
          )
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.2.0")
        context "with parameterized arguments" do
          it "sets the arguments on the transaction" do
            perform_mailer(ActionMailerTestJob, :welcome, parameterized_given_args)

            transaction = last_transaction
            expect(transaction).to have_action("ActionMailerTestJob#welcome")
            expect(transaction).to include_params(
              [
                "ActionMailerTestJob",
                "welcome",
                "deliver_now"
              ] + active_job_args_wrapper(:params => parameterized_expected_args)
            )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end
        end
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("6.0.0")
      context "with ActionMailer MailDeliveryJob job" do
        include ActionMailerHelpers

        before do
          stub_const("ActionMailerTestMailDeliveryJob", Class.new(ActionMailer::Base) do
            self.delivery_job = ActionMailer::MailDeliveryJob

            def welcome(*_args)
            end
          end)
        end

        it "sets the Action mailer data on the transaction" do
          perform_mailer(ActionMailerTestMailDeliveryJob, :welcome)

          transaction = last_transaction
          expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
          expect(transaction).to include_params(
            [
              "ActionMailerTestMailDeliveryJob",
              "welcome",
              "deliver_now",
              { active_job_internal_key => ["args"], "args" => [] }
            ]
          )
          expect(transaction).to include_tags(
            "active_job_id" => kind_of(String),
            "request_id" => kind_of(String),
            "queue" => "mailers",
            "executions" => 1
          )
        end

        context "with method arguments" do
          it "sets the Action mailer data on the transaction" do
            perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, method_given_args)

            transaction = last_transaction
            expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
            expect(transaction).to include_params(
              [
                "ActionMailerTestMailDeliveryJob",
                "welcome",
                "deliver_now",
                {
                  active_job_internal_key => ["args"],
                  "args" => method_expected_args
                }
              ]
            )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end
        end

        context "with parameterized arguments" do
          it "sets the Action mailer data on the transaction" do
            perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, parameterized_given_args)

            transaction = last_transaction
            expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
            expect(transaction).to include_params(
                [
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["params", "args"],
                    "args" => [],
                    "params" => parameterized_expected_args
                  }
                ]
              )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end
        end
      end
    end

    def with_test_adapter
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.performed_jobs.clear
      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
      yield
    ensure
      ActiveJob::Base.queue_adapter = :inline # Restore to default
    end

    def perform_active_job(&block)
      Timecop.freeze(time, &block)
    end

    def queue_job(job_class, args = nil)
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
