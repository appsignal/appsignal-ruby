describe Appsignal::Hooks::PumaHook do
  context "with puma" do
    let(:puma_version) { "6.0.0" }
    before do
      stub_const("Puma", PumaMock)
      stub_const("Puma::Const::VERSION", puma_version)
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      context "when Puma present" do
        context "when Puma is newer than version 3.0.0" do
          let(:puma_version) { "3.0.0" }

          it { is_expected.to be_truthy }
        end

        context "when Puma is older than version 3.0.0" do
          let(:puma_version) { "2.9.9" }

          it { is_expected.to be_falsey }
        end
      end

      context "when Puma is not present" do
        before do
          hide_const("Puma")
        end

        it { is_expected.to be_falsey }
      end
    end

    describe "installation" do
      before { Appsignal::Probes.probes.clear }

      it "adds the Puma::Server patch" do
        Appsignal::Hooks::PumaHook.new.install
        expect(::Puma::Server.included_modules).to include(Appsignal::Integrations::PumaServer)
      end

      context "when not clustered mode" do
        it "does not add AppSignal stop behavior Puma::Cluster" do
          expect(defined?(::Puma::Cluster)).to be_falsy
          # Does not error on call
          Appsignal::Hooks::PumaHook.new.install
        end
      end

      context "when in clustered mode" do
        before do
          stub_const("Puma::Cluster", Class.new do
            def stop_workers
              @called = true
            end
          end)
        end

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
