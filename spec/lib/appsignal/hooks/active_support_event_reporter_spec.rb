describe Appsignal::Hooks::ActiveSupportEventReporterHook do
  begin
    require "active_support/event_reporter"
  rescue LoadError # rubocop:disable Lint/SuppressedException
  end

  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    if DependencyHelper.rails8_1_present?
      context "when ActiveSupport::EventReporter is present" do
        it { is_expected.to be_truthy }
      end
    else
      context "when ActiveSupport::EventReporter is not present" do
        it { is_expected.to be_falsy }
      end
    end
  end

  if defined?(::ActiveSupport::EventReporter)
    describe "#install" do
      before do
        # Mock Rails.event
        subscribers = []
        mock_event_reporter = instance_double(
          "ActiveSupport::EventReporter",
          :subscribe => nil,
          :subscribers => subscribers
        )

        allow(mock_event_reporter).to receive(:subscribe) do |subscriber|
          subscribers << subscriber
        end

        allow(Rails).to receive(:event).and_return(mock_event_reporter)
      end

      it "subscribes the ActiveSupportEventReporter::Subscriber to Rails.event" do
        event_reporter = Rails.event
        expect(event_reporter.subscribers).to be_empty

        described_class.new.install

        expect(event_reporter.subscribers.length).to eq(1)
        expect(event_reporter.subscribers.first).to be_a(Appsignal::Integrations::ActiveSupportEventReporter::Subscriber)
      end
    end
  end
end
