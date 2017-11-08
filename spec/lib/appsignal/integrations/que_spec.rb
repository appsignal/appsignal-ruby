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
          :args => %w(1 birds),
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
          :params => %w(1 birds)
        }
      end

      let(:job) do
        Class.new(::Que::Job) do
          def run(*args)
          end
        end
      end
      let(:instance) { job.new(job_attrs) }
      let(:transaction) do
        Appsignal::Transaction.new(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(env)
        )
      end

      before do
        allow(Que).to receive(:execute)

        start_agent
        expect(Appsignal.active?).to be_truthy
        transaction

        expect(Appsignal::Transaction).to receive(:create)
          .with(
            kind_of(String),
            Appsignal::Transaction::BACKGROUND_JOB,
            kind_of(Appsignal::Transaction::GenericRequest)
          ).and_return(transaction)
        allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
        expect(transaction.ext).to receive(:finish).and_return(true)
        expect(transaction.ext).to receive(:complete)
      end

      subject { transaction.to_h }

      context "success" do
        it "creates a transaction for a job" do
          expect do
            instance._run
          end.to_not raise_exception

          expect(subject).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(subject["error"]).to be_nil
          expect(subject["events"].first).to include(
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
          expect(subject["sample_data"]).to include(
            "params" => %w(1 birds),
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

        it "should report exceptions and re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect do
            instance._run
          end.to raise_error(ExampleException)

          expect(subject).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(subject["error"]).to include(
            "backtrace" => kind_of(String),
            "name" => error.class.name,
            "message" => error.message
          )
          expect(subject["sample_data"]).to include(
            "params" => %w(1 birds),
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

        it "should report errors and not re-raise them" do
          allow(instance).to receive(:run).and_raise(error)

          expect do
            instance._run
          end.to_not raise_error

          expect(subject).to include(
            "action" => "MyQueJob#run",
            "id" => instance_of(String),
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB
          )
          expect(subject["error"]).to include(
            "backtrace" => kind_of(String),
            "name" => error.class.name,
            "message" => error.message
          )
          expect(subject["sample_data"]).to include(
            "params" => %w(1 birds),
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
    end
  end
end
