if DependencyHelper.delayed_job_present?
  require "delayed_job"
  require "appsignal/integrations/delayed_job_plugin"
  # Delayed Job ships an in-memory test backend in its own `spec/` dir. Loading
  # it lets us drive the real enqueue/perform lifecycle without a database.
  require "#{Gem::Specification.find_by_name("delayed_job").gem_dir}/spec/delayed/backend/test"

  describe "Delayed Job integration" do
    before do
      Delayed::Worker.backend = Delayed::Backend::Test::Job
      Delayed::Worker.delay_jobs = true
      Delayed::Backend::Test::Job.delete_all

      # Register our plugin exactly once on a fresh lifecycle. Delayed Job
      # registers a plugin's callbacks when it instantiates the plugin (via
      # `setup_lifecycle`); resetting the list and rebuilding per-example keeps
      # the enqueue/perform from being instrumented more than once, whatever the
      # AppSignal hook may have appended to the list.
      Delayed::Worker.plugins.delete(Appsignal::Integrations::DelayedJobPlugin)
      Delayed::Worker.plugins << Appsignal::Integrations::DelayedJobPlugin
      Delayed::Worker.setup_lifecycle

      stub_const("DelayedTestJob", Class.new do
        def perform
        end
      end)
    end

    # `invoke_job` runs the real `:invoke_job` lifecycle (and re-raises on
    # error). Unlike `Delayed::Worker#run` it doesn't rebuild the lifecycle or
    # swallow the job's exception, so it drives our instrumentation directly.
    def perform_job(job)
      job.invoke_job
    end

    describe "enqueueing a job" do
      context "with an active transaction" do
        it "records an enqueue event titled after the job" do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          Delayed::Job.enqueue(DelayedTestJob.new)

          event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.delayed_job" }
          expect(event).to_not be_nil
          expect(event["title"]).to eq("enqueue DelayedTestJob job")
        end
      end

      context "with a custom appsignal_name" do
        before do
          stub_const("DelayedNamedJob", Class.new do
            def perform
            end

            def appsignal_name
              "CustomName#perform"
            end
          end)
        end

        it "titles the enqueue event with the custom name" do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          Delayed::Job.enqueue(DelayedNamedJob.new)

          event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.delayed_job" }
          expect(event["title"]).to eq("enqueue CustomName#perform job")
        end
      end

      context "without an active transaction" do
        it "is a transparent pass-through" do
          start_agent

          expect { Delayed::Job.enqueue(DelayedTestJob.new) }
            .to change { Delayed::Backend::Test::Job.count }.by(1)
        end
      end

      if DependencyHelper.active_job_present?
        context "when wrapped by Active Job" do
          # Active Job records its own `enqueue.active_job` event and suppresses
          # the backend's, so no duplicate is recorded here.
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :delayed_job
            ActiveJob::Base.logger = nil

            stub_const("DelayedActiveJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          it "does not record a second enqueue event" do
            start_agent
            transaction = http_request_transaction
            set_current_transaction(transaction)

            DelayedActiveJob.perform_later

            event_names = transaction.to_h["events"].map { |e| e["name"] }
            expect(event_names).to include("enqueue.active_job")
            expect(event_names).to_not include("enqueue.delayed_job")
          end
        end
      end
    end

    describe "performing a job" do
      context "with a normal job" do
        it "wraps it in a background_job transaction" do
          start_agent
          job = Delayed::Job.enqueue(DelayedTestJob.new)

          keep_transactions { perform_job(job) }

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("DelayedTestJob#perform")
          expect(transaction).to_not have_error
          expect(transaction).to include_event(:name => "perform_job.delayed_job")
          expect(transaction).to include_tags("attempts" => 0, "priority" => 0)
        end
      end

      context "with a job that raises" do
        before do
          stub_const("DelayedErrorJob", Class.new do
            def perform
              raise ExampleException, "uh oh"
            end
          end)
        end

        it "records the error on the transaction" do
          start_agent
          job = Delayed::Job.enqueue(DelayedErrorJob.new)

          keep_transactions do
            expect { perform_job(job) }.to raise_error(ExampleException, "uh oh")
          end

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("DelayedErrorJob#perform")
          expect(transaction).to have_error("ExampleException", "uh oh")
        end
      end

      context "with a custom appsignal_name" do
        before do
          stub_const("DelayedNamedJob", Class.new do
            def perform
            end

            def appsignal_name
              "CustomName#perform"
            end
          end)
        end

        it "uses the custom name as the action" do
          start_agent
          job = Delayed::Job.enqueue(DelayedNamedJob.new)

          keep_transactions { perform_job(job) }

          expect(last_transaction).to have_action("CustomName#perform")
        end
      end

      if DependencyHelper.active_job_present?
        context "when wrapped by Active Job" do
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :delayed_job
            ActiveJob::Base.logger = nil

            stub_const("DelayedActiveJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          it "uses the Active Job class as the action" do
            start_agent

            keep_transactions do
              DelayedActiveJob.perform_later("arg")
              perform_job(Delayed::Backend::Test::Job.all.last)
            end

            transaction = last_transaction
            expect(transaction).to have_namespace("background_job")
            expect(transaction).to have_action("DelayedActiveJob#perform")
            expect(transaction).to include_params(["arg"])
          end
        end
      end
    end

    describe ".extract_value" do
      let(:plugin) { Appsignal::Integrations::DelayedJobPlugin }

      before { start_agent }

      context "for a hash" do
        let(:hash) { { :key => "value", :bool_false => false } }

        it "reads an existing key" do
          expect(plugin.extract_value(hash, :key)).to eq("value")
        end

        it "reads a false value" do
          expect(plugin.extract_value(hash, :bool_false)).to be(false)
        end

        it "returns the default for a missing key" do
          expect(plugin.extract_value(hash, :nope, 1)).to eq(1)
        end
      end

      context "for an object" do
        let(:object) { double(:existing_method => "value") }

        it "reads an existing method" do
          expect(plugin.extract_value(object, :existing_method)).to eq("value")
        end

        it "returns the default for a missing method" do
          expect(plugin.extract_value(object, :nope, 1)).to eq(1)
        end
      end

      it "converts the value to a string when asked" do
        object = double(:existing_method => 1)
        expect(plugin.extract_value(object, :existing_method, nil, true)).to eq("1")
      end
    end
  end
end
