if DependencyHelper.que_present?
  require "appsignal/integrations/que"

  describe Appsignal::Integrations::QuePlugin do
    describe "#_run" do
      let(:job_attrs) do
        {
          :job_id => 123,
          :queue => "dfl",
          :job_class => "MyQueJob",
          :priority => 100,
          :args => %w[1 birds],
          :run_at => fixed_time,
          :error_count => 0
        }
      end
      let(:env) do
        {
          :class => "MyQueJob",
          :method => "run",
          :metadata => {
            :id => 123,
            :queue => "dfl",
            :priority => 100,
            :run_at => fixed_time.to_s,
            :attempts => 0
          },
          :params => %w[1 birds]
        }
      end
      let(:job) do
        Class.new(::Que::Job) do
          def run(*args)
          end
        end
      end
      let(:instance) { job.new(job_attrs) }
      before do
        allow(Que).to receive(:execute)

        start_agent
        expect(Appsignal.active?).to be_truthy
      end
      around { |example| keep_transactions { example.run } }

      def perform_job(job)
        job._run
      end

      context "success" do
        it "creates a transaction for a job" do
          expect do
            perform_job(instance)
          end.to change { created_transactions.length }.by(1)

          expect(last_transaction).to be_completed
          transaction_hash = last_transaction.to_h
          expect(transaction_hash).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(transaction_hash["error"]).to be_nil
          expect(transaction_hash["events"].first).to include(
            "allocation_count" => kind_of(Integer),
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "child_allocation_count" => kind_of(Integer),
            "child_duration" => kind_of(Float),
            "child_gc_duration" => kind_of(Float),
            "count" => 1,
            "gc_duration" => kind_of(Float),
            "start" => kind_of(Float),
            "duration" => kind_of(Float),
            "name" => "perform_job.que",
            "title" => ""
          )
          expect(transaction_hash["sample_data"]).to include(
            "params" => %w[1 birds],
            "metadata" => {
              "attempts" => 0,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            }
          )
        end
      end

      context "with exception" do
        let(:error) { ExampleException.new("oh no!") }

        it "reports exceptions and re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect do
            expect do
              perform_job(instance)
            end.to raise_error(ExampleException)
          end.to change { created_transactions.length }.by(1)

          expect(last_transaction).to be_completed
          transaction_hash = last_transaction.to_h
          expect(transaction_hash).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(transaction_hash["error"]).to include(
            "backtrace" => kind_of(String),
            "name" => error.class.name,
            "message" => error.message
          )
          expect(transaction_hash["sample_data"]).to include(
            "params" => %w[1 birds],
            "metadata" => {
              "attempts" => 0,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            }
          )
        end
      end

      context "with error" do
        let(:error) { ExampleStandardError.new("oh no!") }

        it "reports errors and not re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect { perform_job(instance) }.to change { created_transactions.length }.by(1)

          expect(last_transaction).to be_completed
          transaction_hash = last_transaction.to_h
          expect(transaction_hash).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(transaction_hash["error"]).to include(
            "backtrace" => kind_of(String),
            "name" => error.class.name,
            "message" => error.message
          )
          expect(transaction_hash["sample_data"]).to include(
            "params" => %w[1 birds],
            "metadata" => {
              "attempts" => 0,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            }
          )
        end
      end

      context "when action set in job" do
        let(:job) do
          Class.new(::Que::Job) do
            def run(*_args)
              Appsignal.set_action("MyCustomJob#perform")
            end
          end
        end

        it "uses the custom action" do
          perform_job(instance)

          expect(last_transaction).to be_completed
          transaction_hash = last_transaction.to_h
          expect(transaction_hash).to include("action" => "MyCustomJob#perform")
        end
      end
    end
  end
end
