describe Appsignal::Hooks::UnicornHook do
  context "with unicorn" do
    before do
      stub_const("Unicorn", Module.new)
      stub_const("Unicorn::HttpServer", Class.new do
        def worker_loop(_worker)
          @worker_loop = true
        end

        def worker_loop?
          @worker_loop == true
        end
      end)
      stub_const("Unicorn::Worker", Class.new do
        def close
          @close = true
        end

        def close?
          @close == true
        end
      end)
      Appsignal::Hooks::UnicornHook.new.install
    end

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
