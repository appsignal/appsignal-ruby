describe Appsignal::Hooks::PgbusHook do
  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    context "when Pgbus::ActiveJob::Executor is defined" do
      before do
        stub_const("Pgbus::ActiveJob::Executor", Class.new)
      end

      it { is_expected.to be_truthy }
    end

    context "when Pgbus is not defined" do
      before { hide_const("Pgbus") }

      it { is_expected.to be_falsy }
    end
  end

  describe "#install" do
    before do
      stub_const("Pgbus::ActiveJob::Executor", Class.new)
      stub_const("Pgbus::EventBus::Handler", Class.new)
      start_agent
    end

    it "prepends PgbusExecutorPlugin to Pgbus::ActiveJob::Executor" do
      described_class.new.install

      expect(Pgbus::ActiveJob::Executor.ancestors).to include(
        Appsignal::Integrations::PgbusExecutorPlugin
      )
    end

    it "prepends PgbusHandlerPlugin to Pgbus::EventBus::Handler" do
      described_class.new.install

      expect(Pgbus::EventBus::Handler.ancestors).to include(
        Appsignal::Integrations::PgbusHandlerPlugin
      )
    end

    context "when Pgbus::Streams::Stream is defined" do
      before do
        stub_const("Pgbus::Streams::Stream", Class.new)
      end

      it "prepends PgbusStreamPlugin to Pgbus::Streams::Stream" do
        described_class.new.install

        expect(Pgbus::Streams::Stream.ancestors).to include(
          Appsignal::Integrations::PgbusStreamPlugin
        )
      end
    end

    context "when Pgbus::Web::DataSource is defined" do
      before do
        stub_const("Pgbus::Web::DataSource", Class.new)
      end

      it "registers the PgbusProbe" do
        described_class.new.install

        expect(Appsignal::Probes.probes[:pgbus]).to eq(Appsignal::Probes::PgbusProbe)
      end
    end
  end
end
