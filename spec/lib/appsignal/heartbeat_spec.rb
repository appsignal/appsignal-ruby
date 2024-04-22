describe Appsignal::Heartbeat do
  let(:config) { project_fixture_config }
  let(:heartbeat) { described_class.new(:name => "heartbeat-name") }
  let(:transmitter) { Appsignal::Transmitter.new("http://heartbeats/", config) }

  before(:each) do
    allow(Appsignal).to receive(:active?).and_return(true)
    config.logger = Logger.new(StringIO.new)
    allow(Appsignal::Heartbeat).to receive(:transmitter).and_return(transmitter)
  end

  describe "when Appsignal is not active" do
    it "should not transmit any events" do
      allow(Appsignal).to receive(:active?).and_return(false)
      expect(transmitter).not_to receive(:transmit)

      heartbeat.start
      heartbeat.finish
    end
  end

  describe "#start" do
    it "should send a heartbeat start" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :name => "heartbeat-name",
        :kind => "start"
      )).and_return(nil)

      heartbeat.start
    end
  end

  describe "#finish" do
    it "should send a heartbeat finish" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :name => "heartbeat-name",
        :kind => "finish"
      )).and_return(nil)

      heartbeat.finish
    end
  end

  describe ".heartbeat" do
    describe "when a block is given" do
      it "should send a heartbeat start and finish and return the block output" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :name => "heartbeat-with-block"
        )).and_return(nil)

        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "finish",
          :name => "heartbeat-with-block"
        )).and_return(nil)

        output = Appsignal.heartbeat("heartbeat-with-block") { "output" }
        expect(output).to eq("output")
      end

      it "should not send a heartbeat finish event when an error is raised" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :name => "heartbeat-with-block"
        )).and_return(nil)

        expect(transmitter).not_to receive(:transmit).with(hash_including(
          :kind => "finish",
          :name => "heartbeat-with-block"
        ))

        expect do
          Appsignal.heartbeat("heartbeat-with-block") { raise "error" }
        end.to raise_error(RuntimeError, "error")
      end
    end

    describe "when no block is given" do
      it "should only send a heartbeat finish event" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "finish",
          :name => "heartbeat-without-block"
        )).and_return(nil)

        Appsignal.heartbeat("heartbeat-without-block")
      end
    end
  end
end
