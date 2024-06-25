describe Appsignal::Heartbeat do
  let(:err_stream) { std_stream }

  after do
    Appsignal.instance_variable_set(:@heartbeat_constant_deprecation_warning_emitted, false)
  end

  it "returns the Cron constant calling the Heartbeat constant" do
    silence { expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron) }
  end

  it "prints a deprecation warning to STDERR" do
    capture_std_streams(std_stream, err_stream) do
      expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
    end

    expect(err_stream.read)
      .to include("appsignal WARNING: The constant Appsignal::Heartbeat has been deprecated.")
  end

  it "does not print a deprecation warning to STDERR more than once" do
    capture_std_streams(std_stream, err_stream) do
      expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
    end

    expect(err_stream.read)
      .to include("appsignal WARNING: The constant Appsignal::Heartbeat has been deprecated.")

    err_stream.truncate(0)

    capture_std_streams(std_stream, err_stream) do
      expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
    end

    expect(err_stream.read)
      .not_to include("appsignal WARNING: The constant Appsignal::Heartbeat has been deprecated.")
  end

  it "logs a warning" do
    logs =
      capture_logs do
        silence do
          expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
        end
      end

    expect(logs).to contains_log(
      :warn,
      "The constant Appsignal::Heartbeat has been deprecated."
    )
  end

  it "does not log a warning more than once" do
    logs =
      capture_logs do
        silence do
          expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
        end
      end

    expect(logs).to contains_log(
      :warn,
      "The constant Appsignal::Heartbeat has been deprecated."
    )

    logs =
      capture_logs do
        silence do
          expect(Appsignal::Heartbeat).to be(Appsignal::CheckIn::Cron)
        end
      end

    expect(logs).not_to contains_log(
      :warn,
      "The constant Appsignal::Heartbeat has been deprecated."
    )
  end
end

describe "Appsignal.heartbeat" do
  let(:err_stream) { std_stream }

  before do
    Appsignal.instance_variable_set(:@heartbeat_helper_deprecation_warning_emitted, false)
  end

  it "should forward the call to Appsignal::CheckIn.cron" do
    expect(Appsignal::CheckIn).to receive(:cron).with("heartbeat-name")
    expect do
      Appsignal.heartbeat("heartbeat-name")
    end.not_to raise_error

    block = proc { 42 }
    expect(Appsignal::CheckIn).to receive(:cron).with("heartbeat-name") do |&given_block|
      expect(given_block).to be(block)
    end.and_return("output")
    expect(Appsignal.heartbeat("heartbeat-name", &block)).to eq("output")
  end

  it "prints a deprecation warning to STDERR" do
    capture_std_streams(std_stream, err_stream) do
      Appsignal.heartbeat("heartbeat-name")
    end

    expect(err_stream.read)
      .to include("appsignal WARNING: The helper Appsignal.heartbeat has been deprecated.")
  end

  it "does not print a deprecation warning to STDERR more than once" do
    capture_std_streams(std_stream, err_stream) do
      Appsignal.heartbeat("heartbeat-name")
    end

    expect(err_stream.read)
      .to include("appsignal WARNING: The helper Appsignal.heartbeat has been deprecated.")

    err_stream.truncate(0)

    capture_std_streams(std_stream, err_stream) do
      Appsignal.heartbeat("heartbeat-name")
    end

    expect(err_stream.read)
      .not_to include("appsignal WARNING: The helper Appsignal.heartbeat has been deprecated.")
  end

  it "logs a warning" do
    logs =
      capture_logs do
        silence do
          Appsignal.heartbeat("heartbeat-name")
        end
      end

    expect(logs).to contains_log(
      :warn,
      "The helper Appsignal.heartbeat has been deprecated."
    )
  end

  it "does not log a warning more than once" do
    logs =
      capture_logs do
        silence do
          Appsignal.heartbeat("heartbeat-name")
        end
      end

    expect(logs).to contains_log(
      :warn,
      "The helper Appsignal.heartbeat has been deprecated."
    )

    logs =
      capture_logs do
        silence do
          Appsignal.heartbeat("heartbeat-name")
        end
      end

    expect(logs).not_to contains_log(
      :warn,
      "The helper Appsignal.heartbeat has been deprecated."
    )
  end
end

describe Appsignal::CheckIn::Cron do
  let(:config) { project_fixture_config }
  let(:cron_checkin) { described_class.new(:name => "cron-checkin-name") }
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
        :name => "cron-checkin-name",
        :kind => "start"
      )).and_return(Net::HTTPResponse.new(nil, "200", nil))

      expect(Appsignal.internal_logger).to receive(:debug).with(
        "Transmitted cron check-in `cron-checkin-name` (#{cron_checkin.id}) start event"
      )
      expect(Appsignal.internal_logger).not_to receive(:error)

      cron_checkin.start
    end

    it "should log an error if it fails" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :name => "cron-checkin-name",
        :kind => "start"
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
        :name => "cron-checkin-name",
        :kind => "finish"
      )).and_return(Net::HTTPResponse.new(nil, "200", nil))

      expect(Appsignal.internal_logger).to receive(:debug).with(
        "Transmitted cron check-in `cron-checkin-name` (#{cron_checkin.id}) finish event"
      )
      expect(Appsignal.internal_logger).not_to receive(:error)

      cron_checkin.finish
    end

    it "should log an error if it fails" do
      expect(transmitter).to receive(:transmit).with(hash_including(
        :name => "cron-checkin-name",
        :kind => "finish"
      )).and_return(Net::HTTPResponse.new(nil, "499", nil))

      expect(Appsignal.internal_logger).not_to receive(:debug)
      expect(Appsignal.internal_logger).to receive(:error).with(
        "Failed to transmit cron check-in finish event: status code was 499"
      )

      cron_checkin.finish
    end
  end

  describe ".cron_checkin" do
    describe "when a block is given" do
      it "should send a cron check-in start and finish and return the block output" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :name => "cron-checkin-with-block"
        )).and_return(nil)

        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "finish",
          :name => "cron-checkin-with-block"
        )).and_return(nil)

        output = Appsignal::CheckIn.cron("cron-checkin-with-block") { "output" }
        expect(output).to eq("output")
      end

      it "should not send a cron check-in finish event when an error is raised" do
        expect(transmitter).to receive(:transmit).with(hash_including(
          :kind => "start",
          :name => "cron-checkin-with-block"
        )).and_return(nil)

        expect(transmitter).not_to receive(:transmit).with(hash_including(
          :kind => "finish",
          :name => "cron-checkin-with-block"
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
          :name => "cron-checkin-without-block"
        )).and_return(nil)

        Appsignal::CheckIn.cron("cron-checkin-without-block")
      end
    end
  end
end
