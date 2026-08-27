require_relative "active_support_notifications/instrument_shared_examples"

# Some gemfiles install Active Support as a dependency of another gem and
# never require this part of it, so ask for it rather than relying on
# something else having loaded it.
if DependencyHelper.active_support_present?
  require "active_support"
  require "active_support/notifications"
end

describe Appsignal::Hooks::ActiveSupportNotificationsHook do
  if active_support_present?
    let(:notifier) { ActiveSupport::Notifications::Fanout.new }
    let(:as) { ActiveSupport::Notifications }

    # The shared examples swap in a fresh notifier (`as.notifier = notifier`) to
    # control which subscriptions are active. Restore the original afterwards so
    # the swap doesn't leak into later specs -- e.g. ActionMailer's
    # instrumentation, which subscribes on the default notifier and would
    # otherwise fire into the stale, subscription-less notifier left behind.
    around do |example|
      original_notifier = ActiveSupport::Notifications.notifier
      example.run
    ensure
      ActiveSupport::Notifications.notifier = original_notifier
    end

    # The before hook swaps in a fresh notifier (`as.notifier = notifier`) to
    # control which subscriptions are active. Restore the original afterwards so
    # the swap doesn't leak into later specs -- e.g. ActionMailer's
    # instrumentation, which subscribes on the default notifier and would
    # otherwise fire into the stale, subscription-less notifier left behind.
    around do |example|
      original_notifier = ActiveSupport::Notifications.notifier
      example.run
    ensure
      ActiveSupport::Notifications.notifier = original_notifier
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it_behaves_like "activesupport instrument override"

    if defined?(::ActiveSupport::Notifications::Fanout::Handle)
      require_relative "active_support_notifications/start_finish_shared_examples"

      it_behaves_like "activesupport start finish override"
    end

    if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:start)
      require_relative "active_support_notifications/start_finish_shared_examples"

      it_behaves_like "activesupport start finish override"
    end

    if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:finish_with_state)
      require_relative "active_support_notifications/finish_with_state_shared_examples"

      it_behaves_like "activesupport finish_with_state override"
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
