describe Appsignal::Hooks::PumaHook do
  context "with puma" do
    before(:all) do
      class Puma
        def self.cli_config
          @cli_config ||= CliConfig.new
        end

        class Cluster
          def stop_workers
          end
        end
      end

      class CliConfig
        attr_accessor :options

        def initialize
          @options = {}
        end
      end
    end
    after(:all) { Object.send(:remove_const, :Puma) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    context "when installed" do
      before do
        Appsignal::Hooks::PumaHook.new.install
      end

      it "adds behavior to Unicorn::Worker#close" do
        cluster = Puma::Cluster.new

        expect(Appsignal).to receive(:stop)
        expect(cluster).to receive(:stop_workers_without_appsignal)

        cluster.stop_workers
      end
    end

    context "with nil hooks" do
      before do
        Puma.cli_config.options.delete(:before_worker_boot)
        Puma.cli_config.options.delete(:before_worker_shutdown)
        Appsignal::Hooks::PumaHook.new.install
      end

      it "should add a before shutdown worker callback" do
        expect(Puma.cli_config.options[:before_worker_boot].first).to be_a(Proc)
        expect(Puma.cli_config.options[:before_worker_shutdown].first).to be_a(Proc)
      end
    end

    context "with existing hooks" do
      before do
        Puma.cli_config.options[:before_worker_boot] = []
        Puma.cli_config.options[:before_worker_shutdown] = []
        Appsignal::Hooks::PumaHook.new.install
      end

      it "should add a before shutdown worker callback" do
        expect(Puma.cli_config.options[:before_worker_boot].first).to be_a(Proc)
        expect(Puma.cli_config.options[:before_worker_shutdown].first).to be_a(Proc)
      end
    end
  end

  context "without puma" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
