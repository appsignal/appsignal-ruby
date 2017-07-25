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

    it "instruments an ActiveSupport::Notifications.instrument event" do
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

    it "should convert non-string names to strings" do
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("not_a_string", nil, nil, nil)

      as.instrument(:not_a_string) {}
    end

    it "does not instrument events whose name starts with a bang" do
      expect(Appsignal::Transaction.current).not_to receive(:start_event)
      expect(Appsignal::Transaction.current).not_to receive(:finish_event)

      return_value = as.instrument("!sql.active_record", :sql => "SQL") do
        "value"
      end

      expect(return_value).to eq "value"
    end

    context "when an error is raised in an instrumented block" do
      it "instruments an ActiveSupport::Notifications.instrument event" do
        expect(Appsignal::Transaction.current).to receive(:start_event)
          .at_least(:once)
        expect(Appsignal::Transaction.current).to receive(:finish_event)
          .at_least(:once)
          .with("sql.active_record", nil, "SQL", 1)

        expect do
          as.instrument("sql.active_record", :sql => "SQL") do
            raise VerySpecificError, "foo"
          end
        end.to raise_error(VerySpecificError, "foo")
      end
    end

    context "when a message is thrown in an instrumented block" do
      it "instruments an ActiveSupport::Notifications.instrument event" do
        expect(Appsignal::Transaction.current).to receive(:start_event)
          .at_least(:once)
        expect(Appsignal::Transaction.current).to receive(:finish_event)
          .at_least(:once)
          .with("sql.active_record", nil, "SQL", 1)

        expect do
          as.instrument("sql.active_record", :sql => "SQL") do
            throw :foo
          end
        end.to throw_symbol(:foo)
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
