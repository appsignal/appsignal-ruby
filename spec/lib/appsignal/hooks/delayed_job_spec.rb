describe Appsignal::Hooks::DelayedJobHook do
  context "with delayed job" do
    before do
      stub_const("Delayed::Plugin", Class.new do
        def self.callbacks
        end
      end)
      stub_const("Delayed::Worker", Class.new do
        def self.plugins
          @plugins ||= []
        end
      end)
      # Install the hook directly rather than through `start_agent`. Hooks
      # install once per process and are never reset, so relying on
      # `start_agent` made "adds the plugin" pass only when this spec was the
      # first to install the Delayed Job hook -- it saw an empty stubbed worker
      # (and failed) once any other spec had installed it first. Mirrors the
      # Shoryuken hook spec.
      described_class.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "adds the plugin" do
      expect(::Delayed::Worker.plugins).to include(Appsignal::Integrations::DelayedJobPlugin)
    end
  end

  context "without delayed job" do
    # Hide the constant so this passes whether or not the gem is loaded (it is
    # under the `delayed_job` gemfile).
    before { hide_const "Delayed::Plugin" }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
