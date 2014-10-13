require 'spec_helper'

describe Appsignal::Event do

  describe "#sanitize!" do
    let(:payload) { {:foo => 'bar'} }
    let(:event) { Appsignal::Event.new('event.test', 1, 2, 3, payload) }

    it "should call the sanitizer" do
      expect( Appsignal::ParamsSanitizer ).to receive(:sanitize).with(payload)
      event.sanitize!
    end

    it "should store the result on the payload" do
      Appsignal::ParamsSanitizer.stub(:sanitize => {:foo => 'sanitized'})
      expect {
        event.sanitize!
      }.to change(event, :payload).from(:foo => 'bar').to(:foo => 'sanitized')
    end
  end

  describe "#truncate!" do
    let(:payload) { {:foo => 'bar'} }
    let(:event) { Appsignal::Event.new('event.test', 1, 2, 3, payload) }

    it "should remove the payload" do
      expect {
        event.truncate!
      }.to change(event, :payload).from(:foo => 'bar').to({})
    end
  end

  describe ".event_for_instrumentation" do
    context "with non-moped event" do
      it "should instantiate a new Appsignal::Event" do
        expect( Appsignal::Event ).to receive(:new)
        Appsignal::Event.event_for_instrumentation('query.active_record')
      end
    end

    context "with moped event" do
      it "should instantiate a moped event" do
        expect( Appsignal::Event::MopedEvent ).to receive(:new)
        Appsignal::Event.event_for_instrumentation('query.moped')
      end
    end
  end
end
