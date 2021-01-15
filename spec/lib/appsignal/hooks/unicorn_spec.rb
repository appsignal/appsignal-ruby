describe Appsignal::Hooks::UnicornHook do
  context "with unicorn" do
    before :context do
      module Unicorn
        class HttpServer
          def worker_loop(_worker)
            @worker_loop = true
          end

          def worker_loop?
            @worker_loop == true
          end
        end

        class Worker
          def close
            @close = true
          end

          def close?
            @close == true
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

      server.worker_loop(worker)

      expect(server.worker_loop?).to be true
    end

    it "adds behavior to Unicorn::Worker#close" do
      worker = Unicorn::Worker.new

      expect(Appsignal).to receive(:stop)

      worker.close
      expect(worker.close?).to be true
    end
  end

  context "without unicorn" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
