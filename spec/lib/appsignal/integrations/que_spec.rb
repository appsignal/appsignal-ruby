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

      def perform_que_job(job)
        job._run
      end

      context "success" do
        it "creates a transaction for a job" do
          expect do
            perform_que_job(instance)
          end.to change { created_transactions.length }.by(1)

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
          expect(transaction).to have_action("MyQueJob#run")
          expect(transaction).to_not have_error
          expect(transaction).to include_event(
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "count" => 1,
            "name" => "perform_job.que",
            "title" => ""
          )
          expect(transaction).to include_params(%w[1 birds])
          expect(transaction).to include_sample_metadata(
            "attempts" => 0,
            "id" => 123,
            "priority" => 100,
            "queue" => "dfl",
            "run_at" => fixed_time.to_s
          )
          expect(transaction).to be_completed
        end
      end

      context "with exception" do
        let(:error) { ExampleException.new("oh no!") }

        it "reports exceptions and re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect do
            expect do
              perform_que_job(instance)
            end.to raise_error(ExampleException)
          end.to change { created_transactions.length }.by(1)

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_action("MyQueJob#run")
          expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
          expect(transaction).to have_error(error.class.name, error.message)
          expect(transaction).to include_params(%w[1 birds])
          expect(transaction).to include_sample_metadata(
            "attempts" => 0,
            "id" => 123,
            "priority" => 100,
            "queue" => "dfl",
            "run_at" => fixed_time.to_s
          )
          expect(transaction).to be_completed
        end
      end

      context "with error" do
        let(:error) { ExampleStandardError.new("oh no!") }

        it "reports errors and not re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect { perform_que_job(instance) }.to change { created_transactions.length }.by(1)

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_action("MyQueJob#run")
          expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
          expect(transaction).to have_error(error.class.name, error.message)
          expect(transaction).to include_params(%w[1 birds])
          expect(transaction).to include_sample_metadata(
            "attempts" => 0,
            "id" => 123,
            "priority" => 100,
            "queue" => "dfl",
            "run_at" => fixed_time.to_s
          )
          expect(transaction).to be_completed
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
          perform_que_job(instance)

          transaction = last_transaction
          expect(transaction).to have_action("MyCustomJob#perform")
          expect(transaction).to be_completed
        end
      end
    end
  end
end
