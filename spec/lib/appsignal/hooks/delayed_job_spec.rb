describe Appsignal::Hooks::DelayedJobHook do
  context "with delayed job" do
    before(:context) do
      module Delayed
        class Plugin
          def self.callbacks
          end
        end

        class Worker
          def self.plugins
            @plugins ||= []
          end
        end
      end
    end
    after(:context) { Object.send(:remove_const, :Delayed) }
    before { start_agent }

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
