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
      let(:payload_object) { double(:args => args) }
      let(:job_data) do
        {
          :id => 123,
          :name => "TestClass#perform",
          :priority => 1,
          :attempts => 1,
          :queue => "default",
          :created_at => created_at,
          :run_at => run_at,
          :payload_object => payload_object
        }
      end
      let(:args) { ["argument"] }
      let(:job) { double(job_data) }
      let(:invoked_block) { proc {} }

      def perform
        Timecop.freeze(time) do
          keep_transactions do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end
        end
      end

      context "with a normal call" do
        it "wraps it in a transaction" do
          perform
          transaction_data = last_transaction.to_h
          expect(transaction_data).to include(
            "action" => "TestClass#perform",
            "namespace" => "background_job",
            "error" => nil
          )
          expect(transaction_data["events"].map { |e| e["name"] })
            .to eql(["perform_job.delayed_job"])
          expect(transaction_data["sample_data"]).to include(
            "metadata" => {
              "priority" => 1,
              "attempts" => 1,
              "queue" => "default",
              "id" => "123"
            },
            "params" => ["argument"]
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
            perform
            transaction_data = last_transaction.to_h
            expect(transaction_data["sample_data"]).to include(
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
              perform
              transaction_data = last_transaction.to_h
              expect(transaction_data["sample_data"]).to include(
                "params" => {
                  "foo" => "[FILTERED]",
                  "bar" => "Bar"
                }
              )
            end
          end
        end

        context "with run_at in the future" do
          let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

          it "reports queue_start with run_at time" do
            # TODO: Not available in transaction.to_h yet.
            # https://github.com/appsignal/appsignal-agent/issues/293
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.delayed_job",
              a_hash_including(:queue_start => run_at)
            ).and_call_original
            perform
          end
        end

        context "with class method job" do
          let(:job_data) do
            { :name => "CustomClassMethod.perform", :payload_object => payload_object }
          end

          it "wraps it in a transaction using the class method job name" do
            perform
            expect(last_transaction.to_h["action"]).to eql("CustomClassMethod.perform")
          end
        end

        context "with custom name call" do
          before { perform }

          context "with appsignal_name defined" do
            context "with payload_object being an object" do
              context "with value" do
                let(:payload_object) { double(:appsignal_name => "CustomClass#perform") }

                it "wraps it in a transaction using the custom name" do
                  expect(last_transaction.to_h["action"]).to eql("CustomClass#perform")
                end
              end

              context "with non-String value" do
                let(:payload_object) { double(:appsignal_name => Object.new) }

                it "wraps it in a transaction using the original job name" do
                  expect(last_transaction.to_h["action"]).to eql("TestClass#perform")
                end
              end

              context "with class method name as job" do
                let(:payload_object) { double(:appsignal_name => "CustomClassMethod.perform") }

                it "wraps it in a transaction using the custom name" do
                  perform
                  expect(last_transaction.to_h["action"]).to eql("CustomClassMethod.perform")
                end
              end
            end

            context "with payload_object being a Hash" do
              context "with value" do
                let(:payload_object) { double(:appsignal_name => "CustomClassHash#perform") }

                it "wraps it in a transaction using the custom name" do
                  expect(last_transaction.to_h["action"]).to eql("CustomClassHash#perform")
                end
              end

              context "with non-String value" do
                let(:payload_object) { double(:appsignal_name => Object.new) }

                it "wraps it in a transaction using the original job name" do
                  expect(last_transaction.to_h["action"]).to eql("TestClass#perform")
                end
              end

              context "with class method name as job" do
                let(:payload_object) { { :appsignal_name => "CustomClassMethod.perform" } }

                it "wraps it in a transaction using the custom name" do
                  perform
                  expect(last_transaction.to_h["action"]).to eql("CustomClassMethod.perform")
                end
              end
            end

            context "with payload_object acting like a Hash and returning a non-String value" do
              class ClassActingAsHash
                def self.[](_key)
                  Object.new
                end

                def self.appsignal_name
                  "ClassActingAsHash#perform"
                end
              end
              let(:payload_object) { ClassActingAsHash }

              # We check for hash values before object values
              # this means ClassActingAsHash returns `Object.new` instead
              # of `self.appsignal_name`. Since this isn't a valid `String`
              # we return the default job name as action name.
              it "wraps it in a transaction using the original job name" do
                expect(last_transaction.to_h["action"]).to eql("TestClass#perform")
              end
            end
          end
        end

        context "with only job class name" do
          let(:job_data) do
            { :name => "Banana", :payload_object => payload_object }
          end

          it "appends #perform to the class name" do
            perform
            expect(last_transaction.to_h["action"]).to eql("Banana#perform")
          end
        end

        if active_job_present?
          require "active_job"

          context "when wrapped by ActiveJob" do
            let(:payload_object) do
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
                :payload_object => payload_object
              )
            end
            let(:args) { ["activejob_argument"] }

            it "wraps it in a transaction with the correct params" do
              perform
              transaction_data = last_transaction.to_h
              expect(transaction_data).to include(
                "action" => "TestClass#perform",
                "namespace" => "background_job",
                "error" => nil
              )
              expect(transaction_data["events"].map { |e| e["name"] })
                .to eql(["perform_job.delayed_job"])
              expect(transaction_data["sample_data"]).to include(
                "metadata" => {
                  "priority" => 1,
                  "attempts" => 1,
                  "queue" => "default",
                  "id" => "123"
                },
                "params" => ["activejob_argument"]
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
                perform
                transaction_data = last_transaction.to_h
                expect(transaction_data).to include("action" => "TestClass#perform")
                expect(transaction_data["sample_data"]).to include(
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
                  perform
                  transaction_data = last_transaction.to_h
                  expect(transaction_data).to include("action" => "TestClass#perform")
                  expect(transaction_data["sample_data"]).to include(
                    "params" => {
                      "foo" => "[FILTERED]",
                      "bar" => "Bar"
                    }
                  )
                end
              end
            end

            context "with run_at in the future" do
              let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

              it "reports queue_start with run_at time" do
                expect(Appsignal).to receive(:monitor_transaction).with(
                  "perform_job.delayed_job",
                  a_hash_including(:queue_start => run_at)
                ).and_call_original
                perform
              end
            end
          end
        end
      end

      context "with an erroring call" do
        let(:error) { ExampleException.new("uh oh") }
        before do
          expect(invoked_block).to receive(:call).and_raise(error)
        end

        it "adds the error to the transaction" do
          expect do
            perform
          end.to raise_error(error)

          transaction_data = last_transaction.to_h
          expect(transaction_data).to include(
            "action" => "TestClass#perform",
            "namespace" => "background_job",
            "error" => {
              "name" => "ExampleException",
              "message" => "uh oh",
              # TODO: backtrace should be an Array of Strings
              # https://github.com/appsignal/appsignal-agent/issues/294
              "backtrace" => kind_of(String)
            }
          )
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
