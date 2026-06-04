require "appsignal/integrations/active_support_event_reporter"

describe Appsignal::Integrations::ActiveSupportEventReporter::Subscriber do
  let(:subscriber) { described_class.new }
  let(:event) do
    {
      :name => "user.created",
      :payload => { :id => 123, :email => "user@example.com" }
    }
  end

  describe "#emit" do
    it "in agent mode", :agent_mode do
      logger = instance_double(Appsignal::Logger)
      allow(Appsignal::Logger).to receive(:new).with("rails_events").and_return(logger)

      expect(logger).to receive(:info).with(
        "user.created",
        { :id => 123, :email => "user@example.com" }
      )

      subscriber.emit(event)
    end

    it "in collector mode", :collector_mode do
      subscriber.emit(event)

      expect(log_records.size).to eq(1)
      record = log_records.first
      expect(record).not_to be_nil
      expect(record.body).to eq("user.created")
      expect(record.severity_number).to eq(9)
      expect(record.severity_text).to eq("INFO")
      expect(record.attributes).to include(
        "id" => 123,
        "email" => "user@example.com",
        "appsignal.group" => "rails_events"
      )
    end
  end
end
