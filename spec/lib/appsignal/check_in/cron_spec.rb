describe Appsignal::CheckIn::Cron do
  let(:log_stream) { std_stream }
  let(:logs) { log_contents(log_stream) }
  let(:appsignal_options) { {} }
  let(:config) { project_fixture_config }
  let(:cron_checkin) { described_class.new(:identifier => "cron-checkin-name") }
  let(:scheduler) { Appsignal::CheckIn.scheduler }

  before do
    start_agent(
      :options => appsignal_options,
      :internal_logger => test_logger(log_stream)
    )
  end
  after { stop_scheduler }

  def stop_scheduler
    scheduler.stop
  end

  describe "when Appsignal is not active" do
    let(:appsignal_options) { { :active => false } }

    it "does not transmit any events" do
      expect(Appsignal).to_not be_started

      cron_checkin.start
      cron_checkin.finish
      stop_scheduler

      expect(logs).to contains_log(
        :debug,
        /Cannot transmit cron check-in `cron-checkin-name` start event .+: AppSignal is not active/
      )
      expect(logs).to contains_log(
        :debug,
        /Cannot transmit cron check-in `cron-checkin-name` finish event .+: AppSignal is not active/
      )
    end
  end

  describe "when AppSignal is stopped" do
    it "does not transmit any events" do
      Appsignal.stop

      cron_checkin.start
      cron_checkin.finish

      expect(logs).to contains_log(
        :debug,
        "Cannot transmit cron check-in `cron-checkin-name` start event"
      )
      expect(logs).to contains_log(
        :debug,
        "Cannot transmit cron check-in `cron-checkin-name` finish event"
      )
    end
  end

  describe "#start" do
    it "sends a cron check-in start" do
      cron_checkin.start

      stub_check_in_request(
        :events => [
          "identifier" => "cron-checkin-name",
          "kind" => "start",
          "check_in_type" => "cron"
        ]
      )

      scheduler.stop

      expect(logs).to_not contains_log(:error)
      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `cron-checkin-name` start event"
      )
      expect(logs).to contains_log(
        :debug,
        "Transmitted cron check-in `cron-checkin-name` start event"
      )
    end

    it "logs an error if it fails" do
      cron_checkin.start

      stub_check_in_request(
        :events => [
          "identifier" => "cron-checkin-name",
          "kind" => "start",
          "check_in_type" => "cron"
        ],
        :response => { :status => 499 }
      )

      scheduler.stop

      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `cron-checkin-name` start event"
      )
      expect(logs).to contains_log(
        :error,
        /Failed to transmit cron check-in `cron-checkin-name` start event .+: 499 status code/
      )
    end
  end

  describe "#finish" do
    it "sends a cron check-in finish" do
      cron_checkin.finish

      stub_check_in_request(
        :events => [
          "identifier" => "cron-checkin-name",
          "kind" => "finish",
          "check_in_type" => "cron"
        ]
      )

      scheduler.stop
      expect(logs).to_not contains_log(:error)
      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `cron-checkin-name` finish event"
      )
      expect(logs).to contains_log(
        :debug,
        "Transmitted cron check-in `cron-checkin-name` finish event"
      )
    end

    it "logs an error if it fails" do
      cron_checkin.finish

      stub_check_in_request(
        :events => [
          "identifier" => "cron-checkin-name",
          "kind" => "finish",
          "check_in_type" => "cron"
        ],
        :response => { :status => 499 }
      )

      scheduler.stop

      expect(logs).to contains_log(
        :debug,
        "Scheduling cron check-in `cron-checkin-name` finish event"
      )
      expect(logs).to contains_log(
        :error,
        /Failed to transmit cron check-in `cron-checkin-name` finish event .+: 499 status code/
      )
    end
  end

  describe ".cron" do
    describe "when a block is given" do
      it "sends a cron check-in start and finish and return the block output" do
        stub_check_in_request(
          :events => [
            "identifier" => "cron-checkin-with-block",
            "kind" => "start",
            "check_in_type" => "cron"
          ]
        )
        stub_check_in_request(
          :events => [
            "identifier" => "cron-checkin-with-block",
            "kind" => "finish",
            "check_in_type" => "cron"
          ]
        )

        output = Appsignal::CheckIn.cron("cron-checkin-with-block") { "output" }
        expect(output).to eq("output")
      end

      it "does not send a cron check-in finish event when an error is raised" do
        stub_check_in_request(
          :events => [
            "identifier" => "cron-checkin-with-block",
            "kind" => "start",
            "check_in_type" => "cron"
          ]
        )

        expect do
          Appsignal::CheckIn.cron("cron-checkin-with-block") { raise "error" }
        end.to raise_error(RuntimeError, "error")
      end
    end

    describe "when no block is given" do
      it "only sends a cron check-in finish event" do
        stub_check_in_request(
          :events => [
            "identifier" => "cron-checkin-without-block",
            "kind" => "finish",
            "check_in_type" => "cron"
          ]
        )

        Appsignal::CheckIn.cron("cron-checkin-without-block")
      end
    end
  end
end
