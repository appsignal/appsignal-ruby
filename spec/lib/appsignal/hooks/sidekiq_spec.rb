describe Appsignal::Hooks::SidekiqPlugin do
  if DependencyHelper.sidekiq_present?
    let(:worker) { double }
    let(:queue) { double }
    let(:current_transaction) { background_job_transaction }
    let(:args) { ["Model", 1] }
    let(:item) do
      {
        "class"       => "TestClass",
        "retry_count" => 0,
        "queue"       => "default",
        "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f,
        "args"        => args,
        "extra"       => "data"
      }
    end
    let(:plugin) { Appsignal::Hooks::SidekiqPlugin.new }

    before do
      allow(Appsignal::Transaction).to receive(:current).and_return(current_transaction)
      start_agent
    end

    context "with a performance call" do
      after do
        Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
          Appsignal::Hooks::SidekiqPlugin.new.call(worker, item, queue) do
            # nothing
          end
        end
      end

      it "wraps it in a transaction with the correct params" do
        expect(Appsignal).to receive(:monitor_transaction).with(
          "perform_job.sidekiq",
          :class    => "TestClass",
          :method   => "perform",
          :metadata => {
            "retry_count" => "0",
            "queue"       => "default",
            "extra"       => "data"
          },
          :params      => ["Model", 1],
          :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
          :queue_time  => 60_000.to_f
        )
      end

      context "with more complex arguments" do
        let(:default_params) do
          {
            :class    => "TestClass",
            :method   => "perform",
            :metadata => {
              "retry_count" => "0",
              "queue"       => "default",
              "extra"       => "data"
            },
            :params => args,
            :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
            :queue_time  => 60_000.to_f
          }
        end
        let(:args) do
          {
            :foo => "Foo",
            :bar => "Bar"
          }
        end

        it "adds the more complex arguments" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.sidekiq",
            default_params.merge(
              :params => {
                :foo => "Foo",
                :bar => "Bar"
              }
            )
          )
        end

        context "with parameter filtering" do
          before do
            Appsignal.config = project_fixture_config("production")
            Appsignal.config[:filter_parameters] = ["foo"]
          end

          it "filters selected arguments" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.sidekiq",
              default_params.merge(
                :params => {
                  :foo => "[FILTERED]",
                  :bar => "Bar"
                }
              )
            )
          end

          it "does not modify the given arguments" do
          end
        end

        context "when receiving class.method instead of class#method" do
          let(:item) do
            {
              "class"       => "ActionMailer.deliver_message",
              "retry_count" => 0,
              "queue"       => "default",
              "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f,
              "args"        => args,
              "extra"       => "data"
            }
          end
          it "wraps it in a transaction with the correct params" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.sidekiq",
              :class    => "ActionMailer",
              :method   => "deliver_message",
              :metadata => {
                "retry_count" => "0",
                "queue"       => "default",
                "extra"       => "data"
              },
              :params      => {
                :foo => "Foo",
                :bar => "Bar"
              },
              :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
              :queue_time  => 60_000.to_f
            )
          end
        end
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
              "arguments" => args
            }],
            "retry" => true,
            "jid" => "efb140489485999d32b5504c",
            "created_at" => Time.parse("01-01-2001 10:00:00UTC"),
            "enqueued_at" => Time.parse("01-01-2001 10:00:00UTC").to_f
          }
        end
        let(:default_params) do
          {
            :class    => "TestClass",
            :method   => "perform",
            :metadata => {
              "queue" => "default"
            },
            :queue_start => Time.parse("01-01-2001 10:00:00UTC"),
            :queue_time  => 60_000.to_f
          }
        end

        it "wraps it in a transaction with the correct params" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.sidekiq",
            default_params.merge(:params => ["Model", 1])
          )
        end

        context "with more complex arguments" do
          let(:args) do
            {
              :foo => "Foo",
              :bar => "Bar"
            }
          end

          it "adds the more complex arguments" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.sidekiq",
              default_params.merge(
                :params => {
                  :foo => "Foo",
                  :bar => "Bar"
                }
              )
            )
          end

          context "with parameter filtering" do
            before do
              Appsignal.config = project_fixture_config("production")
              Appsignal.config[:filter_parameters] = ["foo"]
            end

            it "filters selected arguments" do
              expect(Appsignal).to receive(:monitor_transaction).with(
                "perform_job.sidekiq",
                default_params.merge(
                  :params => {
                    :foo => "[FILTERED]",
                    :bar => "Bar"
                  }
                )
              )
            end
          end
        end
      end
    end

    context "with an erroring call" do
      let(:error) { VerySpecificError }
      let(:transaction) do
        Appsignal::Transaction.new(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new({})
        )
      end
      before do
        allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
        expect(Appsignal::Transaction).to receive(:create)
          .with(
            kind_of(String),
            Appsignal::Transaction::BACKGROUND_JOB,
            kind_of(Appsignal::Transaction::GenericRequest)
          ).and_return(transaction)
      end

      it "adds the error to the transaction" do
        expect(transaction).to receive(:set_error).with(error)
        expect(transaction).to receive(:complete)
      end

      after do
        expect do
          Timecop.freeze(Time.parse("01-01-2001 10:01:00UTC")) do
            Appsignal::Hooks::SidekiqPlugin.new.call(worker, item, queue) do
              raise error
            end
          end
        end.to raise_error(error)
      end
    end

    # TODO: Don't test (what are basically) private methods
    describe "#formatted_data" do
      let(:item) do
        {
          "foo"   => "bar",
          "class" => "TestClass"
        }
      end

      it "only adds items to the hash that do not appear in JOB_KEYS" do
        expect(plugin.formatted_metadata(item)).to eq("foo" => "bar")
      end
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
