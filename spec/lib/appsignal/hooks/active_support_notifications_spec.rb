describe Appsignal::Hooks::ActiveSupportNotificationsHook do
  if active_support_present?
    let(:notifier) { ActiveSupport::Notifications::Fanout.new }
    let(:as) { ActiveSupport::Notifications }
    before :context do
      start_agent
    end
    before do
      as.notifier = notifier
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "instruments an ActiveSupport::Notifications.instrument call with a block" do
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("sql.active_record", nil, "SQL", 1)

      return_value = as.instrument("sql.active_record", :sql => "SQL") do
        "value"
      end

      expect(return_value).to eq "value"
    end

    it "does not instrument events whose name starts with a bang" do
      expect(Appsignal::Transaction.current).not_to receive(:start_event)
      expect(Appsignal::Transaction.current).not_to receive(:finish_event)

      return_value = as.instrument("!sql.active_record", :sql => "SQL") do
        "value"
      end

      expect(return_value).to eq "value"
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
