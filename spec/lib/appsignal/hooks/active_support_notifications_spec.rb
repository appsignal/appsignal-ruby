describe Appsignal::Hooks::ActiveSupportNotificationsHook do
  if active_support_present?
    before :all do
      start_agent
    end
    before do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
    end

    let(:notifier) { ActiveSupport::Notifications::Fanout.new }
    let(:instrumenter) { ActiveSupport::Notifications::Instrumenter.new(notifier) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "should instrument an AS notifications instrument call with a block" do
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("sql.active_record", nil, "SQL", 1)

      return_value = instrumenter.instrument("sql.active_record", :sql => "SQL") do
        "value"
      end

      expect(return_value).to eq "value"
    end

    it "should not instrument events whose name starts with a bang" do
      expect(Appsignal::Transaction.current).not_to receive(:start_event)
      expect(Appsignal::Transaction.current).not_to receive(:finish_event)

      return_value = instrumenter.instrument("!sql.active_record", :sql => "SQL") do
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
