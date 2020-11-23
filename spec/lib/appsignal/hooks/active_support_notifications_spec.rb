require_relative "./active_support_notifications/instrument_shared_examples"

describe Appsignal::Hooks::ActiveSupportNotificationsHook do
  if active_support_present?
    let(:notifier) { ActiveSupport::Notifications::Fanout.new }
    let(:as) { ActiveSupport::Notifications }
    let!(:transaction) do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
    end
    before :context do
      start_agent
    end
    before do
      as.notifier = notifier
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it_behaves_like "activesupport instrument override"

    if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:start)
      require_relative "./active_support_notifications/start_finish_shared_examples"

      it_behaves_like "activesupport start finish override"
    end

    if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:finish_with_state)
      require_relative "./active_support_notifications/finish_with_state_shared_examples"

      it_behaves_like "activesupport finish_with_state override"
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
