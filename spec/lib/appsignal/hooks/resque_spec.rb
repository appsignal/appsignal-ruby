describe Appsignal::Hooks::ResqueHook do
  describe "#dependency_present?" do
    subject { described_class.new.dependencies_present? }

    context "when Resque is loaded" do
      before { stub_const "Resque", 1 }

      it { is_expected.to be_truthy }
    end

    context "when Resque is not loaded" do
      before { hide_const "Resque" }

      it { is_expected.to be_falsy }
    end
  end

  if DependencyHelper.resque_present?
    describe "#install" do
      def perform_rescue_job(klass, options = {})
        payload = { "class" => klass.to_s }.merge(options)
        job = ::Resque::Job.new(queue, payload)
        keep_transactions { job.perform }
      end

      let(:queue) { "default" }
      let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
      before do
        start_agent

        class ResqueTestJob
          def self.perform(*_args)
          end
        end

        class ResqueErrorTestJob
          def self.perform
            raise "resque job error"
          end
        end

        expect(Appsignal).to receive(:stop) # Resque calls stop after every job
      end
      around do |example|
        keep_transactions { example.run }
      end
      after do
        Object.send(:remove_const, :ResqueTestJob)
        Object.send(:remove_const, :ResqueErrorTestJob)
      end

      it "tracks a transaction on perform" do
        perform_rescue_job(ResqueTestJob)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ResqueTestJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_metadata
        expect(transaction).to_not include_breadcrumbs
        expect(transaction).to include_tags("queue" => queue)
        expect(transaction).to include_event("name" => "perform.resque")
      end

      context "with error" do
        it "tracks the error on the transaction" do
          expect do
            perform_rescue_job(ResqueErrorTestJob)
          end.to raise_error(RuntimeError, "resque job error")

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(namespace)
          expect(transaction).to have_action("ResqueErrorTestJob#perform")
          expect(transaction).to have_error("RuntimeError", "resque job error")
          expect(transaction).to_not include_metadata
          expect(transaction).to_not include_breadcrumbs
          expect(transaction).to include_tags("queue" => queue)
          expect(transaction).to include_event("name" => "perform.resque")
        end
      end

      context "with arguments" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end

        it "filters out configured arguments" do
          perform_rescue_job(
            ResqueTestJob,
            "args" => [
              "foo",
              {
                "foo" => "secret",
                "bar" => "Bar",
                "baz" => { "1" => "foo" }
              }
            ]
          )

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(namespace)
          expect(transaction).to have_action("ResqueTestJob#perform")
          expect(transaction).to_not have_error
          expect(transaction).to_not include_metadata
          expect(transaction).to_not include_breadcrumbs
          expect(transaction).to include_tags("queue" => queue)
          expect(transaction).to include_event("name" => "perform.resque")
          expect(transaction).to include_params(
            [
              "foo",
              {
                "foo" => "[FILTERED]",
                "bar" => "Bar",
                "baz" => { "1" => "foo" }
              }
            ]
          )
        end
      end

      context "with active job" do
        before do
          module ActiveJobMock
            module QueueAdapters
              module ResqueAdapter
                module JobWrapper
                  class << self
                    def perform(job_data)
                      # Basic ActiveJob stub for this test.
                      # I haven't found a way to run Resque in a testing mode.
                      Appsignal.set_action(job_data["job_class"])
                    end
                  end
                end
              end
            end
          end

          stub_const "ActiveJob", ActiveJobMock
        end
        after { Object.send(:remove_const, :ActiveJobMock) }

        it "does not set arguments but lets the ActiveJob integration handle it" do
          perform_rescue_job(
            ResqueTestJob,
            "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
            "args" => [
              {
                "job_class" => "ResqueTestJobByActiveJob#perform",
                "arguments" => ["an argument", "second argument"]
              }
            ]
          )

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(namespace)
          expect(transaction).to have_action("ResqueTestJobByActiveJob#perform")
          expect(transaction).to_not have_error
          expect(transaction).to_not include_metadata
          expect(transaction).to_not include_breadcrumbs
          expect(transaction).to include_tags("queue" => queue)
          expect(transaction).to include_event("name" => "perform.resque")
          expect(transaction).to_not include_params
        end
      end
    end
  end
end
