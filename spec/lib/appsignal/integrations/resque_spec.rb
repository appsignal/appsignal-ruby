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
            raise ExampleException
          end
        end
      end

      describe :around_perform_resque_plugin do
        let(:transaction) { Appsignal::Transaction.new("1", "background", {}, {}) }
        let(:job) { ::Resque::Job.new("default", "class" => "TestJob") }
        before do
          allow(transaction).to receive(:complete).and_return(true)
          allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
          expect(Appsignal).to receive(:stop)
        end

        context "without exception" do
          it "creates a new transaction" do
            expect(Appsignal::Transaction).to receive(:create).and_return(transaction)
          end

          it "wraps it in a transaction with the correct params" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.resque",
              :class => "TestJob",
              :method => "perform"
            )
          end

          it "closes the transaction" do
            expect(transaction).to receive(:complete)
          end

          after { job.perform }
        end

        context "with exception" do
          let(:job) { ::Resque::Job.new("default", "class" => "BrokenTestJob") }
          let(:transaction) do
            Appsignal::Transaction.new(
              SecureRandom.uuid,
              Appsignal::Transaction::BACKGROUND_JOB,
              Appsignal::Transaction::GenericRequest.new({})
            )
          end
          before do
            allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
            expect(Appsignal::Transaction).to receive(:create)
              .with(
                kind_of(String),
                Appsignal::Transaction::BACKGROUND_JOB,
                kind_of(Appsignal::Transaction::GenericRequest)
              ).and_return(transaction)
          end

          it "sets the exception on the transaction" do
            expect(transaction).to receive(:set_error).with(ExampleException)
          end

          after do
            expect { job.perform }.to raise_error(ExampleException)
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
