describe Appsignal::CheckIn::Cron do
  let(:config) { project_fixture_config }
  let(:cron_checkin) { described_class.new(:identifier => "cron-checkin-name") }
  let(:transmitter) { Appsignal::Transmitter.new("https://checkin-endpoint.invalid") }
  let(:scheduler) { Appsignal::CheckIn::Scheduler.new }

  before do
    allow(Appsignal).to receive(:active?).and_return(true)
    config.logger = Logger.new(StringIO.new)
    allow(Appsignal::CheckIn).to receive(:scheduler).and_return(scheduler)
    allow(Appsignal::CheckIn).to receive(:transmitter).and_return(transmitter)
  end

  after do
    scheduler.stop
  end

  describe "when Appsignal is not active" do
    it "should not transmit any events" do
      allow(Appsignal).to receive(:active?).and_return(false)

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Cannot transmit cron check-in `cron-checkin-name` start event") &&
        message.include?("AppSignal is not active")
      end)

      cron_checkin.start

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Cannot transmit cron check-in `cron-checkin-name` finish event") &&
        message.include?("AppSignal is not active")
      end)

      cron_checkin.finish

      expect(transmitter).not_to receive(:transmit)

      scheduler.stop
    end
  end

  describe "when AppSignal is stopped" do
    it "should not transmit any events" do
      expect(transmitter).not_to receive(:transmit)

      expect(Appsignal.internal_logger).to receive(:debug).with("Stopping AppSignal")

      Appsignal.stop

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Cannot transmit cron check-in `cron-checkin-name` start event") &&
        message.include?("AppSignal is stopped")
      end)

      cron_checkin.start

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Cannot transmit cron check-in `cron-checkin-name` finish event") &&
        message.include?("AppSignal is stopped")
      end)

      cron_checkin.finish

      expect(Appsignal.internal_logger).to receive(:debug).with("Stopping AppSignal")

      Appsignal.stop
    end
  end

  describe "#start" do
    it "should send a cron check-in start" do
      expect(Appsignal.internal_logger).not_to receive(:error)

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Scheduling cron check-in `cron-checkin-name` start event")
      end)

      cron_checkin.start

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Transmitted cron check-in `cron-checkin-name` start event")
      end)

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "cron-checkin-name",
        :kind => "start",
        :check_in_type => "cron"
      )], :format => :ndjson).and_return(Net::HTTPResponse.new(nil, "200", nil))

      scheduler.stop
    end

    it "should log an error if it fails" do
      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Scheduling cron check-in `cron-checkin-name` start event")
      end)

      cron_checkin.start

      expect(Appsignal.internal_logger).to receive(:error).with(satisfy do |message|
        message.include?("Failed to transmit cron check-in `cron-checkin-name` start event") &&
          message.include?("499 status code")
      end)

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "cron-checkin-name",
        :kind => "start",
        :check_in_type => "cron"
      )], :format => :ndjson).and_return(Net::HTTPResponse.new(nil, "499", nil))

      scheduler.stop
    end
  end

  describe "#finish" do
    it "should send a cron check-in finish" do
      expect(Appsignal.internal_logger).not_to receive(:error)

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Scheduling cron check-in `cron-checkin-name` finish event")
      end)

      cron_checkin.finish

      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Transmitted cron check-in `cron-checkin-name` finish event")
      end)

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "cron-checkin-name",
        :kind => "finish",
        :check_in_type => "cron"
      )], :format => :ndjson).and_return(Net::HTTPResponse.new(nil, "200", nil))

      scheduler.stop
    end

    it "should log an error if it fails" do
      expect(Appsignal.internal_logger).to receive(:debug).with(satisfy do |message|
        message.include?("Scheduling cron check-in `cron-checkin-name` finish event")
      end)

      cron_checkin.finish

      expect(Appsignal.internal_logger).to receive(:error).with(satisfy do |message|
        message.include?("Failed to transmit cron check-in `cron-checkin-name` finish event") &&
          message.include?("499 status code")
      end)

      expect(transmitter).to receive(:transmit).with([hash_including(
        :identifier => "cron-checkin-name",
        :kind => "finish",
        :check_in_type => "cron"
      )], :format => :ndjson).and_return(Net::HTTPResponse.new(nil, "499", nil))

      scheduler.stop
    end
  end

  describe ".cron" do
    describe "when a block is given" do
      it "should send a cron check-in start and finish and return the block output" do
        expect(scheduler).to receive(:schedule).with(hash_including(
          :kind => "start",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        ))

        expect(scheduler).to receive(:schedule).with(hash_including(
          :kind => "finish",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        ))

        output = Appsignal::CheckIn.cron("cron-checkin-with-block") { "output" }
        expect(output).to eq("output")
      end

      it "should not send a cron check-in finish event when an error is raised" do
        expect(scheduler).to receive(:schedule).with(hash_including(
          :kind => "start",
          :identifier => "cron-checkin-with-block",
          :check_in_type => "cron"
        ))

        expect(scheduler).not_to receive(:schedule).with(hash_including(
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
        expect(scheduler).to receive(:schedule).with(hash_including(
          :kind => "finish",
          :identifier => "cron-checkin-without-block",
          :check_in_type => "cron"
        ))

        Appsignal::CheckIn.cron("cron-checkin-without-block")
      end
    end
  end
end
