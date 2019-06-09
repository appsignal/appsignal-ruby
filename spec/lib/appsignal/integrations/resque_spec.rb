if DependencyHelper.resque_present?
  describe "Resque integration" do
    let(:file) { File.expand_path("lib/appsignal/integrations/resque.rb") }

    context "with resque" do
      before do
        load file
        start_agent

        class TestJob
          extend Appsignal::Integrations::ResquePlugin

          def self.perform
          end
        end

        class BrokenTestJob
          extend Appsignal::Integrations::ResquePlugin

          def self.perform
            raise ExampleException, "my error message"
          end
        end
      end

      describe :around_perform_resque_plugin do
        let(:job) { ::Resque::Job.new("default", "class" => "TestJob") }
        before { expect(Appsignal).to receive(:stop) }

        context "without exception" do
          it "creates a new transaction" do
            expect do
              keep_transactions { job.perform }
            end.to change { created_transactions.length }.by(1)

            expect(last_transaction.to_h).to include(
              "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
              "action" => "TestJob#perform",
              "error" => nil,
              "events" => [
                hash_including(
                  "name" => "perform_job.resque",
                  "title" => "",
                  "body" => "",
                  "body_format" => Appsignal::EventFormatter::DEFAULT,
                  "count" => 1,
                  "duration" => kind_of(Float)
                )
              ]
            )
          end
        end

        context "with exception" do
          let(:job) { ::Resque::Job.new("default", "class" => "BrokenTestJob") }

          def perform
            keep_transactions do
              expect do
                job.perform
              end.to raise_error(ExampleException, "my error message")
            end
          end

          it "sets the exception on the transaction" do
            expect do
              perform
            end.to change { created_transactions.length }.by(1)

            expect(last_transaction.to_h).to include(
              "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
              "action" => "BrokenTestJob#perform",
              "error" => {
                "name" => "ExampleException",
                "message" => "my error message",
                "backtrace" => kind_of(String)
              }
            )
          end
        end
      end
    end

    context "without resque" do
      before(:context) { Object.send(:remove_const, :Resque) }

      it { expect { ::Resque }.to raise_error(NameError) }
      it { expect { load file }.to_not raise_error }
    end
  end
end
