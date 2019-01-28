describe Appsignal::Hooks::DelayedJobHook do
  context "with delayed job" do
    before(:context) do
      module Delayed
        class Plugin
          def self.callbacks
          end
        end

        class Worker
          def self.plugins
            @plugins ||= []
          end
        end
      end
    end
    after(:context) { Object.send(:remove_const, :Delayed) }
    before do
      start_agent
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "adds the plugin" do
      expect(::Delayed::Worker.plugins).to include Appsignal::Hooks::DelayedJobPlugin
    end

    # We haven't found a way to test the hooks, we'll have to do that manually

    describe ".invoke_with_instrumentation" do
      let(:plugin) { Appsignal::Hooks::DelayedJobPlugin }
      let(:time) { Time.parse("01-01-2001 10:01:00UTC") }
      let(:created_at) { time - 3600 }
      let(:run_at) { time - 3600 }
      let(:job_data) do
        {
          :id             => 123,
          :name           => "TestClass#perform",
          :priority       => 1,
          :attempts       => 1,
          :queue          => "default",
          :created_at     => created_at,
          :run_at         => run_at,
          :payload_object => double(:args => args)
        }
      end
      let(:args) { ["argument"] }
      let(:job) { double(job_data) }
      let(:invoked_block) { proc {} }

      context "with a normal call" do
        let(:default_params) do
          {
            :class    => "TestClass",
            :method   => "perform",
            :metadata => {
              :priority => 1,
              :attempts => 1,
              :queue    => "default",
              :id       => "123"
            },
            :params      => args,
            :queue_start => run_at
          }
        end
        after do
          Timecop.freeze(time) do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end
        end

        it "wraps it in a transaction with the correct params" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.delayed_job",
            default_params.merge(:params => ["argument"])
          )
        end

        context "with more complex params" do
          let(:args) do
            {
              :foo => "Foo",
              :bar => "Bar"
            }
          end

          it "adds the more complex arguments" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.delayed_job",
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
                "perform_job.delayed_job",
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

        context "with run_at in the future" do
          let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

          it "reports queue_start with run_at time" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.delayed_job",
              default_params.merge(:queue_start => run_at)
            )
          end
        end

        context "with custom name call" do
          let(:job_data) do
            {
              :payload_object => double(
                :appsignal_name => "CustomClass#perform",
                :args           => args
              ),
              :id         => "123",
              :name       => "TestClass#perform",
              :priority   => 1,
              :attempts   => 1,
              :queue      => "default",
              :created_at => created_at,
              :run_at     => run_at
            }
          end
          let(:default_params) do
            {
              :class => "CustomClass",
              :method => "perform",
              :metadata => {
                :priority => 1,
                :attempts => 1,
                :queue    => "default",
                :id       => "123"
              },
              :queue_start => run_at
            }
          end

          it "wraps it in a transaction with the correct params" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.delayed_job",
              default_params.merge(
                :params => ["argument"]
              )
            )
          end

          context "with more complex params" do
            let(:args) do
              {
                :foo => "Foo",
                :bar => "Bar"
              }
            end

            it "adds the more complex arguments" do
              expect(Appsignal).to receive(:monitor_transaction).with(
                "perform_job.delayed_job",
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
                  "perform_job.delayed_job",
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

        if active_job_present?
          require "active_job"

          context "when wrapped by ActiveJob" do
            let(:wrapped_job) do
              ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(
                "arguments"  => args,
                "job_class"  => "TestClass",
                "job_id"     => 123,
                "locale"     => :en,
                "queue_name" => "default"
              )
            end
            let(:job) do
              double(
                :id             => 123,
                :name           => "ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper",
                :priority       => 1,
                :attempts       => 1,
                :queue          => "default",
                :created_at     => created_at,
                :run_at         => run_at,
                :payload_object => wrapped_job
              )
            end
            let(:default_params) do
              {
                :class    => "TestClass",
                :method   => "perform",
                :metadata => {
                  :priority => 1,
                  :attempts => 1,
                  :queue    => "default",
                  :id       => "123"
                },
                :queue_start => run_at,
                :params      => args
              }
            end
            let(:args) { ["activejob_argument"] }

            context "with simple params" do
              it "wraps it in a transaction with the correct params" do
                expect(Appsignal).to receive(:monitor_transaction).with(
                  "perform_job.delayed_job",
                  default_params.merge(:params => ["activejob_argument"])
                )
              end
            end

            context "with more complex params" do
              let(:args) do
                {
                  :foo => "Foo",
                  :bar => "Bar"
                }
              end

              it "adds the more complex arguments" do
                expect(Appsignal).to receive(:monitor_transaction).with(
                  "perform_job.delayed_job",
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
                    "perform_job.delayed_job",
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

            context "with run_at in the future" do
              let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

              it "reports queue_start with run_at time" do
                expect(Appsignal).to receive(:monitor_transaction).with(
                  "perform_job.delayed_job",
                  default_params.merge(:queue_start => run_at)
                )
              end
            end
          end
        end
      end

      context "with an erroring call" do
        let(:error) { ExampleException }
        let(:transaction) do
          Appsignal::Transaction.new(
            SecureRandom.uuid,
            Appsignal::Transaction::BACKGROUND_JOB,
            Appsignal::Transaction::GenericRequest.new({})
          )
        end
        before do
          expect(invoked_block).to receive(:call).and_raise(error)

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

          expect do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end.to raise_error(error)
        end
      end
    end

    describe ".extract_value" do
      let(:plugin) { Appsignal::Hooks::DelayedJobPlugin }

      context "for a hash" do
        let(:hash) { { :key => "value", :bool_false => false } }

        context "when the key exists" do
          subject { plugin.extract_value(hash, :key) }

          it { is_expected.to eq "value" }

          context "when the value is false" do
            subject { plugin.extract_value(hash, :bool_false) }

            it { is_expected.to be false }
          end
        end

        context "when the key does not exist" do
          subject { plugin.extract_value(hash, :nonexistent_key) }

          it { is_expected.to be_nil }

          context "with a default value" do
            subject { plugin.extract_value(hash, :nonexistent_key, 1) }

            it { is_expected.to eq 1 }
          end
        end
      end

      context "for a struct" do
        before :context do
          TestStruct = Struct.new(:key)
        end
        let(:struct) { TestStruct.new("value") }

        context "when the key exists" do
          subject { plugin.extract_value(struct, :key) }

          it { is_expected.to eq "value" }
        end

        context "when the key does not exist" do
          subject { plugin.extract_value(struct, :nonexistent_key) }

          it { is_expected.to be_nil }

          context "with a default value" do
            subject { plugin.extract_value(struct, :nonexistent_key, 1) }

            it { is_expected.to eq 1 }
          end
        end
      end

      context "for a struct with a method" do
        before :context do
          class TestStructClass < Struct.new(:id) # rubocop:disable Style/StructInheritance
            def appsignal_name
              "TestStruct#perform"
            end

            def bool_false
              false
            end
          end
        end
        let(:struct) { TestStructClass.new("id") }

        context "when the Struct responds to a method" do
          subject { plugin.extract_value(struct, :appsignal_name) }

          it "returns the method value" do
            is_expected.to eq "TestStruct#perform"
          end

          context "when the value is false" do
            subject { plugin.extract_value(struct, :bool_false) }

            it "returns the method value" do
              is_expected.to be false
            end
          end
        end

        context "when the key does not exist" do
          subject { plugin.extract_value(struct, :nonexistent_key) }

          context "without a method with the same name" do
            it "returns nil" do
              is_expected.to be_nil
            end
          end

          context "with a default value" do
            let(:default_value) { :my_default_value }
            subject { plugin.extract_value(struct, :nonexistent_key, default_value) }

            it "returns the default value" do
              is_expected.to eq default_value
            end
          end
        end
      end

      context "for an object" do
        let(:object) { double(:existing_method => "value") }

        context "when the method exists" do
          subject { plugin.extract_value(object, :existing_method) }

          it { is_expected.to eq "value" }
        end

        context "when the method does not exist" do
          subject { plugin.extract_value(object, :nonexistent_method) }

          it { is_expected.to be_nil }

          context "and there is a default value" do
            subject { plugin.extract_value(object, :nonexistent_method, 1) }

            it { is_expected.to eq 1 }
          end
        end
      end

      context "when we need to call to_s on the value" do
        let(:object) { double(:existing_method => 1) }

        subject { plugin.extract_value(object, :existing_method, nil, true) }

        it { is_expected.to eq "1" }
      end
    end
  end

  context "without delayed job" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
