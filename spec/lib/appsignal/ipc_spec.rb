require 'spec_helper'

describe Appsignal::IPC do
  before :all do
    Appsignal::IPC.init
  end
  let(:agent) { double }

  subject { Appsignal::IPC.current }

  its(:reader) { should be_instance_of(IO) }
  its(:writer) { should be_instance_of(IO) }
  its(:listener) { should be_instance_of(Thread) }
  its(:listening?) { should be_true }

  describe "#write" do
    context "with a regular request" do
      let(:transaction) { regular_transaction }

      it "should dump" do
        Marshal.should_receive(:dump)
      end
    end

    context "when the pipe is closed" do
      let(:transaction) { regular_transaction }
      before { Appsignal.stub(:agent => agent) }

      it "should shutdown" do
        Appsignal::IPC.current.writer.close
        agent.should_receive(:shutdown)
      end
    end

    after { Appsignal::IPC.current.write(transaction) }
  end

  describe "#stop_listening!" do
    before do
      subject.stop_listening!
      sleep 0.1
    end

    it "should have closed the reader" do
      subject.reader.closed?.should be_true
    end

    it "should have killed the listener thread" do
      subject.listener.alive?.should be_false
    end

    it "should not crash when called twice" do
      expect { subject.stop_listening! }.not_to raise_error
    end

    it "should know it's not listening anymore" do
      subject.listening?.should be_false
    end
  end
end
