describe Appsignal::Hooks::ExconHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  context "with Excon" do
    before do
      stub_const("Excon", Module.new)
      stub_const("Excon::Connection", Class.new)
      stub_const("Excon::Middleware", Module.new)
      stub_const("Excon::Middleware::Base", Class.new do
        def initialize(stack = nil)
          @stack = stack
        end
      end)
      stub_const("Excon::Middleware::Mock", Class.new(Excon::Middleware::Base))
      # Mock is the innermost default middleware; the hook inserts ours before it.
      Excon.singleton_class.define_method(:defaults) do
        @defaults ||= { :middlewares => [Excon::Middleware::Mock] }
      end
      Appsignal::Hooks::ExconHook.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }

      context "when Excon instrumentation is disabled" do
        let(:options) { { :instrument_excon => false } }

        it { is_expected.to be_falsy }
      end
    end

    describe "#install" do
      it "adds the AppSignal integration to Excon connections" do
        expect(Excon::Connection.ancestors)
          .to include(Appsignal::Integrations::ExconIntegration)
      end

      it "adds the AppSignal middleware to Excon, before the Mock middleware" do
        middlewares = Excon.defaults[:middlewares]
        expect(middlewares).to include(Appsignal::Integrations::ExconMiddleware)
        expect(middlewares.index(Appsignal::Integrations::ExconMiddleware))
          .to be < middlewares.index(Excon::Middleware::Mock)
      end

      it "does not add the middleware twice when installed again" do
        Appsignal::Hooks::ExconHook.new.install

        expect(
          Excon.defaults[:middlewares].count(Appsignal::Integrations::ExconMiddleware)
        ).to eq(1)
      end
    end
  end

  context "without Excon" do
    before { hide_const "Excon" }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
