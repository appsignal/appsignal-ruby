if DependencyHelper.sidekiq_present?
  describe Appsignal::Hooks::SidekiqPlugin, :with_sidekiq_error => false do
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:worker) { anything }
    let(:queue) { anything }
    let(:args) { ["Model", 1] }
    let(:job_class) { "TestClass" }
    let(:item) do
      {
        "class"       => job_class,
        "retry_count" => 0,
        "queue"       => "default",
        "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f,
        "args"        => args,
        "extra"       => "data"
      }
    end
    let(:plugin) { Appsignal::Hooks::SidekiqPlugin.new }
    let(:test_store) { {} }

    before :with_sidekiq_error => false do
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
    before do
      start_agent
    end
    after { clear_current_transaction! }

    context "when there's a problem with calling the Sidekiq::Job class", :with_sidekiq_error => true do
      let(:log) { StringIO.new }
      before do
        Appsignal.logger = Logger.new(log)
        expect(::Sidekiq::Job).to receive(:new).and_raise(NameError, "woops")
        perform_job
      end

      it "does not record a transaction and logs an error" do
        expect(transaction).to be_nil
        log.rewind
        expect(log.read).to include(
          "ERROR",
          "Problem parsing the Sidekiq job data: #<NameError: woops>"
        )
      end
    end

    context "with a performance call" do
      it "creates a transaction with performance events" do
        perform_job

        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "id" => kind_of(String),
          "action" => "TestClass#perform",
          "error" => nil,
          "namespace" => namespace,
          "metadata" => {
            "extra" => "data",
            "queue" => "default",
            "retry_count" => "0"
          },
          "sample_data" => {
            "environment" => {},
            "params" => args,
            "tags" => {}
          }
        )
        # TODO: Not available in transaction.to_h yet.
        # https://github.com/appsignal/appsignal-agent/issues/293
        expect(transaction.request.env).to eq(
          :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
          :queue_time  => 60_000.0
        )
        expect_transaction_to_have_sidekiq_event(transaction_hash)
      end

      context "when receiving class.method instead of class#method" do
        let(:job_class) { "ActionMailer.deliver_message" }

        it "uses the class method action name for the action" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash["action"]).to eq("ActionMailer.deliver_message")
        end
      end

      context "with more complex job arguments" do
        let(:args) do
          {
            :foo => "Foo",
            :bar => "Bar"
          }
        end

        it "adds the more complex arguments" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash["sample_data"]).to include(
            "params" => {
              "foo" => "Foo",
              "bar" => "Bar"
            }
          )
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
              "params" => {
                "foo" => "[FILTERED]",
                "bar" => "Bar"
              }
            )
          end
        end
      end

      context "when job is wrapped by ActiveJob" do
        let(:item) do
          {
            "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
            "wrapped" => "TestClass",
            "queue" => "default",
            "args" => [{
              "job_class" => "TestJob",
              "job_id" => "23e79d48-6966-40d0-b2d4-f7938463a263",
              "queue_name" => "default",
              "arguments" => args
            }],
            "retry" => true,
            "jid" => "efb140489485999d32b5504c",
            "created_at" => Time.parse("01-01-2001 10:00:00UTC"),
            "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f
          }
        end

        it "creates a transaction with performance events" do
          perform_job

          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "id" => kind_of(String),
            "action" => "TestClass#perform",
            "error" => nil,
            "namespace" => namespace,
            "metadata" => {
              "queue" => "default"
            },
            "sample_data" => {
              "environment" => {},
              "params" => args,
              "tags" => {}
            }
          )
          # TODO: Not available in transaction.to_h yet.
          # https://github.com/appsignal/appsignal-agent/issues/293
          expect(transaction.request.env).to eq(
            :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
            :queue_time  => 60_000.0
          )
          expect_transaction_to_have_sidekiq_event(transaction_hash)
        end

        context "with more complex arguments" do
          let(:args) do
            {
              :foo => "Foo",
              :bar => "Bar"
            }
          end

          it "adds the more complex arguments" do
            perform_job

            transaction_hash = transaction.to_h
            expect(transaction_hash["sample_data"]).to include(
              "params" => {
                "foo" => "Foo",
                "bar" => "Bar"
              }
            )
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
                "params" => {
                  "foo" => "[FILTERED]",
                  "bar" => "Bar"
                }
              )
            end
          end
        end
      end
    end

    context "with an erroring job" do
      let(:error) { ExampleException }
      before do
        expect do
          Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
            plugin.call(worker, item, queue) do
              raise error, "uh oh"
            end
          end
        end.to raise_error(error)
      end

      it "adds the error to the transaction" do
        transaction_hash = transaction.to_h
        # TODO: backtrace should be an Array of Strings
        # https://github.com/appsignal/appsignal-agent/issues/294
        expect(transaction_hash["error"]).to include(
          "name" => "ExampleException",
          "message" => "uh oh",
          "backtrace" => kind_of(String)
        )
        expect_transaction_to_have_sidekiq_event(transaction_hash)
      end
    end

    def perform_job
      Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
        plugin.call(worker, item, queue) do
          # nothing
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
end

describe Appsignal::Hooks::SidekiqHook do
  if DependencyHelper.sidekiq_present?
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
