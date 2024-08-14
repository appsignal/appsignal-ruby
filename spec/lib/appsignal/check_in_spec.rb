describe Appsignal::CheckIn::Cron do
  let(:config) { project_fixture_config }
  let(:cron_checkin) { described_class.new(:identifier => "cron-checkin-name") }
  let(:transmitter) { Appsignal::Transmitter.new("http://cron_checkins/", config) }

  before(:each) do
    allow(Appsignal).to receive(:active?).and_return(true)
    config.logger = Logger.new(StringIO.new)
    allow(Appsignal::CheckIn::Cron).to receive(:transmitter).and_return(transmitter)
  end

  describe "when Appsignal is not active" do
    it "should not transmit any events" do
      allow(Appsignal).to receive(:active?).and_return(false)
      expect(transmitter).not_to receive(:transmit)

      cron_checkin.start
      cron_checkin.finish
    end
  end

  describe "#start" do
    it "should send a cron check-in start" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :identifier => "cron-checkin-name",
        :kind => "start",
        :check_in_type => "cron"
      )).and_return(Net::HTTPResponse.new(nil, "200", nil))

      expect(Appsignal.internal_logger).to receive(:debug).with(
        "Transmitted cron check-in `cron-checkin-name` (#{cron_checkin.digest}) start event"
      )
      expect(Appsignal.internal_logger).not_to receive(:error)

      cron_checkin.start
    end

    it "should log an error if it fails" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :identifier => "cron-checkin-name",
        :kind => "start",
        :check_in_type => "cron"
      )).and_return(Net::HTTPResponse.new(nil, "499", nil))

      expect(Appsignal.internal_logger).not_to receive(:debug)
      expect(Appsignal.internal_logger).to receive(:error).with(
        "Failed to transmit cron check-in start event: status code was 499"
      )

      cron_checkin.start
    end
  end

  describe "#finish" do
    it "should send a cron check-in finish" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :identifier => "cron-checkin-name",
        :kind => "finish",
        :check_in_type => "cron"
      )).and_return(Net::HTTPResponse.new(nil, "200", nil))

      expect(Appsignal.internal_logger).to receive(:debug).with(
        "Transmitted cron check-in `cron-checkin-name` (#{cron_checkin.digest}) finish event"
      )
      expect(Appsignal.internal_logger).not_to receive(:error)

      cron_checkin.finish
    end

    it "should log an error if it fails" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :identifier => "cron-checkin-name",
        :kind => "finish",
        :check_in_type => "cron"
      )).and_return(Net::HTTPResponse.new(nil, "499", nil))

      expect(Appsignal.internal_logger).not_to receive(:debug)
      expect(Appsignal.internal_logger).to receive(:error).with(
        "Failed to transmit cron check-in finish event: status code was 499"
      )

      cron_checkin.finish
    end
  end

  describe ".cron" do
    describe "when a block is given" do
      it "should send a cron check-in start and finish and return the block output" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        )).and_return(nil)

        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "finish",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        )).and_return(nil)

        output = Appsignal::CheckIn.cron("cron-checkin-with-block") { "output" }
        expect(output).to eq("output")
      end

      it "should not send a cron check-in finish event when an error is raised" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        )).and_return(nil)

        expect(transmitter).not_to receive(:transmit).with(hash_including(
          :kind => "finish",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        ))

        expect do
          Appsignal::CheckIn.cron("cron-checkin-with-block") { raise "error" }
        end.to raise_error(RuntimeError, "error")
      end
    end

    describe "when no block is given" do
      it "should only send a cron check-in finish event" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "finish",
          :identifier => "cron-checkin-without-block",
          :check_in_type => "cron"
        )).and_return(nil)

        Appsignal::CheckIn.cron("cron-checkin-without-block")
      end
    end
  end
end
