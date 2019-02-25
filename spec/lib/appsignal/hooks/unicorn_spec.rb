describe Appsignal::Hooks::UnicornHook do
  context "with unicorn" do
    before :context do
      module Unicorn
        class HttpServer
          def worker_loop(worker)
          end
        end

        class Worker
          def close
          end
        end
      end
      Appsignal::Hooks::UnicornHook.new.install
    end
    after(:context) { Object.send(:remove_const, :Unicorn) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "adds behavior to Unicorn::HttpServer#worker_loop" do
      server = Unicorn::HttpServer.new
      worker = double

      expect(Appsignal).to receive(:forked)
      expect(server).to receive(:worker_loop_without_appsignal).with(worker)

      server.worker_loop(worker)
    end

    it "adds behavior to Unicorn::Worker#close" do
      worker = Unicorn::Worker.new

      expect(Appsignal).to receive(:stop)
      expect(worker).to receive(:close_without_appsignal)

      worker.close
    end
  end

  context "without unicorn" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end

describe Appsignal::Hooks::UnicornProbe do
  describe "#call" do
    let(:probe) { described_class.new }

    before do
      module Unicorn
        class HttpServer
          def worker_processes
            3
          end
        end
      end
      Unicorn::HttpServer.new
    end
    after(:context) { Object.send(:remove_const, :Unicorn) }

    it "sends back the amount of activer workers" do
      expect(Appsignal).to receive(:set_gauge)
        .with("unicorn_worker_count", 3)
        .and_call_original

      probe.call
    end
  end
end
