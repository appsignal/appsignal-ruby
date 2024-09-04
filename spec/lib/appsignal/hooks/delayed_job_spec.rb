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
      start_agent
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
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
