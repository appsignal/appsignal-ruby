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
      def perform_job(klass, options = {})
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
        perform_job(ResqueTestJob)

        transaction = last_transaction
        transaction_hash = transaction.to_h
        expect(transaction_hash).to include(
          "id" => kind_of(String),
          "action" => "ResqueTestJob#perform",
          "error" => nil,
          "namespace" => namespace,
          "metadata" => {},
          "sample_data" => {
            "breadcrumbs" => [],
            "tags" => { "queue" => queue }
          }
        )
        expect(transaction_hash["events"].map { |e| e["name"] })
          .to eql(["perform.resque"])
      end

      context "with error" do
        it "tracks the error on the transaction" do
          expect do
            perform_job(ResqueErrorTestJob)
          end.to raise_error(RuntimeError, "resque job error")

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "id" => kind_of(String),
            "action" => "ResqueErrorTestJob#perform",
            "error" => {
              "name" => "RuntimeError",
              "message" => "resque job error",
              "backtrace" => kind_of(String)
            },
            "namespace" => namespace,
            "metadata" => {},
            "sample_data" => {
              "breadcrumbs" => [],
              "tags" => { "queue" => queue }
            }
          )
        end
      end

      context "with arguments" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end

        it "filters out configured arguments" do
          perform_job(
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
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "id" => kind_of(String),
            "action" => "ResqueTestJob#perform",
            "error" => nil,
            "namespace" => namespace,
            "metadata" => {},
            "sample_data" => {
              "tags" => { "queue" => queue },
              "breadcrumbs" => [],
              "params" => [
                "foo",
                {
                  "foo" => "[FILTERED]",
                  "bar" => "Bar",
                  "baz" => { "1" => "foo" }
                }
              ]
            }
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
          perform_job(
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
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "id" => kind_of(String),
            "action" => "ResqueTestJobByActiveJob#perform",
            "error" => nil,
            "namespace" => namespace,
            "metadata" => {},
            "sample_data" => {
              "breadcrumbs" => [],
              "tags" => { "queue" => queue }
              # Params will be set by the ActiveJob integration
            }
          )
        end
      end
    end
  end
end
