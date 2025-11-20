require "appsignal/integrations/active_support_event_reporter"

describe Appsignal::Integrations::ActiveSupportEventReporter::Subscriber do
  let(:subscriber) { described_class.new }
  let(:logger) { instance_double(Appsignal::Logger) }

  before do
    start_agent
    allow(Appsignal::Logger).to receive(:new).with("rails_events").and_return(logger)
  end

  describe "#emit" do
    it "logs the event name and payload" do
      event = {
        :name => "user.created",
        :payload => { :id => 123, :email => "user@example.com" },
      }

      expect(logger).to receive(:info).with("user.created", { :id => 123, :email => "user@example.com" })

      subscriber.emit(event)
    end
  end
end
