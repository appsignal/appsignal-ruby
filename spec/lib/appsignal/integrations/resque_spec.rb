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
            raise VerySpecificError.new
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
          it "should create a new transaction" do
            expect(Appsignal::Transaction).to receive(:create).and_return(transaction)
          end

          it "should wrap in a transaction with the correct params" do
            expect(Appsignal).to receive(:monitor_transaction).with(
              "perform_job.resque",
              :class => "TestJob",
              :method => "perform"
            )
          end

          it "should close the transaction" do
            expect(transaction).to receive(:complete)
          end

          after { job.perform }
        end

        context "with exception" do
          let(:job) { ::Resque::Job.new("default", "class" => "BrokenTestJob") }

          it "should set the exception" do
            expect_any_instance_of(Appsignal::Transaction).to receive(:set_error)
          end

          after do
            begin
              job.perform
            rescue VerySpecificError
              # Do nothing
            end
          end
        end
      end
    end

    context "without resque" do
      before(:all) { Object.send(:remove_const, :Resque) }

      specify { expect { ::Resque }.to raise_error(NameError) }
      specify { expect { load file }.to_not raise_error }
    end
  end
end
