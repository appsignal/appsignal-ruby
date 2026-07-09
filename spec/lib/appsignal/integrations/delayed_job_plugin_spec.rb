describe "Appsignal::Integrations::DelayedJobHook" do
  let(:options) { {} }
  before do
    stub_const("Delayed", Module.new)
    stub_const("Delayed::Plugin", Class.new do
      def self.callbacks
      end
    end)
    stub_const("Delayed::Worker", Class.new do
      def self.plugins
        @plugins ||= []
      end
    end)
    require "appsignal/integrations/delayed_job_plugin"
  end

  # We haven't found a way to test the hooks, we'll have to do that manually

  describe ".invoke_with_instrumentation" do
    let(:plugin) { Appsignal::Integrations::DelayedJobPlugin }
    let(:time) { Time.parse("01-01-2001 10:01:00UTC") }
    let(:created_at) { time - 3600 }
    let(:run_at) { time - 3600 }
    let(:payload_object) { double(:args => args) }
    let(:start_agent_args) { { :options => options } }
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
        plugin.invoke_with_instrumentation(job, invoked_block)
      end
    end

    context "with a normal call" do
      describe "wraps it in a transaction" do
        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("TestClass#perform")
          expect(transaction).to_not have_error
          expect(transaction).to include_event(:name => "perform_job.delayed_job")
          expect(transaction).to include_tags(
            "priority" => 1,
            "attempts" => 1,
            "queue" => "default",
            "id" => "123"
          )
          expect(transaction).to include_params(["argument"])
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(exception_events).to be_empty
          span = event_spans.find { |s| s.name == "perform_job.delayed_job" }
          expect(span).not_to be_nil
          expect(span.parent_span_id).to eq(root_span.span_id)
          expect(span.attributes).not_to have_key("appsignal.body")
          expect(span.attributes["appsignal.category"]).to eq("perform_job.delayed_job")
          expect(root_span.attributes["appsignal.tag.priority"]).to eq(1)
          expect(root_span.attributes["appsignal.tag.attempts"]).to eq(1)
          expect(root_span.attributes["appsignal.tag.queue"]).to eq("default")
          expect(root_span.attributes["appsignal.tag.id"]).to eq("123")
          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
            .to eq(["argument"])
        end
      end

      # Regression for the rake-launched-worker collision: Delayed Job workers
      # are booted via `rake jobs:work`, so when
      # `enable_rake_performance_instrumentation` is on, RakeIntegration opens a
      # "rake" transaction that stays active on the thread while the worker loop
      # runs. `Transaction.create` is not re-entrant -- with a transaction
      # already active it returns that one and discards the passed namespace --
      # so the job is absorbed into the "rake" transaction instead of getting
      # its own background_job transaction.
      describe "with a rake transaction already active (rake-launched worker)" do
        def perform
          # Mimics Appsignal::Integrations::RakeIntegration wrapping the
          # long-running `jobs:work` task.
          Appsignal::Transaction.create("rake")
          Timecop.freeze(time) do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end
        end

        it "records the job under its own background_job namespace", :agent_mode do
          start_agent(**start_agent_args)
          perform

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("TestClass#perform")
        end

        it "records the job as its own consumer trace", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
        end
      end

      context "with more complex params" do
        let(:args) do
          {
            :foo => "Foo",
            :bar => "Bar"
          }
        end

        describe "adds the more complex arguments" do
          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to include_params("foo" => "Foo", "bar" => "Bar")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq("foo" => "Foo", "bar" => "Bar")
          end
        end

        context "with parameter filtering" do
          let(:options) { { :filter_parameters => ["foo"] } }

          describe "filters selected arguments" do
            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to include_params("foo" => "[FILTERED]", "bar" => "Bar")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq("foo" => "[FILTERED]", "bar" => "Bar")
            end
          end
        end
      end

      context "with run_at in the future" do
        let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

        it "reports queue_start with run_at time", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(last_transaction).to have_queue_start(run_at.to_i * 1000)
        end
      end

      context "with class method job" do
        let(:job_data) do
          { :name => "CustomClassMethod.perform", :payload_object => payload_object }
        end

        describe "wraps it in a transaction using the class method job name" do
          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to have_action("CustomClassMethod.perform")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.attributes["appsignal.action_name"])
              .to eq("CustomClassMethod.perform")
          end
        end
      end

      context "with custom name call" do
        context "with appsignal_name defined" do
          context "with payload_object being an object" do
            context "with value" do
              let(:payload_object) { double(:appsignal_name => "CustomClass#perform") }

              describe "wraps it in a transaction using the custom name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("CustomClass#perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("CustomClass#perform")
                end
              end
            end

            context "with non-String value" do
              let(:payload_object) { double(:appsignal_name => Object.new) }

              describe "wraps it in a transaction using the original job name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("TestClass#perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("TestClass#perform")
                end
              end
            end

            context "with class method name as job" do
              let(:payload_object) { double(:appsignal_name => "CustomClassMethod.perform") }

              describe "wraps it in a transaction using the custom name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("CustomClassMethod.perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("CustomClassMethod.perform")
                end
              end
            end
          end

          context "with payload_object being a Hash" do
            context "with value" do
              let(:payload_object) { double(:appsignal_name => "CustomClassHash#perform") }

              describe "wraps it in a transaction using the custom name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("CustomClassHash#perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("CustomClassHash#perform")
                end
              end
            end

            context "with non-String value" do
              let(:payload_object) { double(:appsignal_name => Object.new) }

              describe "wraps it in a transaction using the original job name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("TestClass#perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("TestClass#perform")
                end
              end
            end

            context "with class method name as job" do
              let(:payload_object) { { :appsignal_name => "CustomClassMethod.perform" } }

              describe "wraps it in a transaction using the custom name" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  expect(last_transaction).to have_action("CustomClassMethod.perform")
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("CustomClassMethod.perform")
                end
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
            describe "wraps it in a transaction using the original job name" do
              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                expect(last_transaction).to have_action("TestClass#perform")
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(root_span.attributes["appsignal.action_name"])
                  .to eq("TestClass#perform")
              end
            end
          end
        end
      end

      context "with only job class name" do
        let(:job_data) do
          { :name => "Banana", :payload_object => payload_object }
        end

        describe "appends #perform to the class name" do
          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to have_action("Banana#perform")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.attributes["appsignal.action_name"]).to eq("Banana#perform")
          end
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

          describe "wraps it in a transaction with the correct params" do
            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              transaction = last_transaction
              expect(transaction).to have_namespace("background_job")
              expect(transaction).to have_action("TestClass#perform")
              expect(transaction).to_not have_error
              expect(transaction).to include_event("name" => "perform_job.delayed_job")
              expect(transaction).to include_tags(
                "priority" => 1,
                "attempts" => 1,
                "queue" => "default",
                "id" => "123"
              )
              expect(transaction).to include_params(["activejob_argument"])
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(root_span.kind).to eq(:consumer)
              expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
              expect(root_span.attributes["appsignal.namespace"]).to eq("background")
              expect(exception_events).to be_empty
              span = event_spans.find { |s| s.name == "perform_job.delayed_job" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
              expect(span.attributes).not_to have_key("appsignal.body")
              expect(span.attributes["appsignal.category"]).to eq("perform_job.delayed_job")
              expect(root_span.attributes["appsignal.tag.priority"]).to eq(1)
              expect(root_span.attributes["appsignal.tag.attempts"]).to eq(1)
              expect(root_span.attributes["appsignal.tag.queue"]).to eq("default")
              expect(root_span.attributes["appsignal.tag.id"]).to eq("123")
              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq(["activejob_argument"])
            end
          end

          context "with more complex params" do
            let(:args) do
              {
                :foo => "Foo",
                :bar => "Bar"
              }
            end

            describe "adds the more complex arguments" do
              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                transaction = last_transaction
                expect(transaction).to have_action("TestClass#perform")
                expect(transaction).to include_params(
                  "foo" => "Foo",
                  "bar" => "Bar"
                )
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
                expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                  .to eq("foo" => "Foo", "bar" => "Bar")
              end
            end

            context "with parameter filtering" do
              let(:options) { { :filter_parameters => ["foo"] } }

              describe "filters selected arguments" do
                it "in agent mode", :agent_mode do
                  start_agent(**start_agent_args)
                  perform

                  transaction = last_transaction
                  expect(transaction).to have_action("TestClass#perform")
                  expect(transaction).to include_params(
                    "foo" => "[FILTERED]",
                    "bar" => "Bar"
                  )
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
                  expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                    .to eq("foo" => "[FILTERED]", "bar" => "Bar")
                end
              end
            end
          end

          context "with run_at in the future" do
            let(:run_at) { Time.parse("2017-01-01 10:01:00UTC") }

            it "reports queue_start with run_at time", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_queue_start(run_at.to_i * 1000)
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

      describe "adds the error to the transaction" do
        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          expect do
            perform
          end.to raise_error(error)

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("TestClass#perform")
          expect(transaction).to have_error("ExampleException", "uh oh")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect do
            perform
          end.to raise_error(error)

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(root_span.attributes["appsignal.action_name"]).to eq("TestClass#perform")
          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("uh oh")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end
    end
  end

  describe ".extract_value" do
    let(:plugin) { Appsignal::Integrations::DelayedJobPlugin }

    before { start_agent }

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
      let(:struct_class) { Struct.new(:key) }
      let(:struct) { struct_class.new("value") }

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
      before do
        stub_const("TestStructClass", Class.new(Struct.new(:id)) do
          def appsignal_name
            "TestStruct#perform"
          end

          def bool_false
            false
          end
        end)
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
