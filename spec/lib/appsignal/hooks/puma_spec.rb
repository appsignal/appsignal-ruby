describe Appsignal::Hooks::PumaHook do
  context "with puma" do
    before(:context) do
      class Puma
        def self.stats
        end

        def self.cli_config
          @cli_config ||= CliConfig.new
        end
      end

      class CliConfig
        attr_accessor :options

        def initialize
          @options = {}
        end
      end
    end
    after(:context) { Object.send(:remove_const, :Puma) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    describe "installation" do
      before { Appsignal::Minutely.probes.clear }

      context "when not clustered mode" do
        it "does not add AppSignal stop behavior Puma::Cluster" do
          expect(defined?(::Puma::Cluster)).to be_falsy
          # Does not error on call
          Appsignal::Hooks::PumaHook.new.install
        end
      end

      context "when in clustered mode" do
        before do
          class Puma
            class Cluster
              def stop_workers
                @called = true
              end
            end
          end
        end
        after { Puma.send(:remove_const, :Cluster) }

        it "adds behavior to Puma::Cluster.stop_workers" do
          Appsignal::Hooks::PumaHook.new.install
          cluster = Puma::Cluster.new

          expect(cluster.instance_variable_defined?(:@called)).to be_falsy
          expect(Appsignal).to receive(:stop).and_call_original
          cluster.stop_workers
          expect(cluster.instance_variable_get(:@called)).to be(true)
        end
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
