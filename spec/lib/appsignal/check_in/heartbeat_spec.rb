describe "Appsignal::CheckIn.heartbeat" do
  include WaitForHelper
  include TakeAtMostHelper

  let(:log_stream) { std_stream }
  let(:logs) { log_contents(log_stream) }
  let(:appsignal_options) { {} }
  let(:config) { project_fixture_config }
  let(:scheduler) { Appsignal::CheckIn.scheduler }
  let(:stubs) { [] }

  before do
    start_agent(
      :options => appsignal_options,
      :internal_logger => test_logger(log_stream)
    )
  end

  after do
    Appsignal::CheckIn.kill_continuous_heartbeats
    scheduler.stop

    stubs.each do |stub|
      expect(stub.count).to eq(1)
    end
  end

  def schedule_heartbeat(**kwargs)
    Appsignal::CheckIn.heartbeat("heartbeat-checkin-name", **kwargs)
  end

  describe "when Appsignal is not active" do
    let(:appsignal_options) { { :active => false } }

    it "does not transmit any events" do
      expect(Appsignal).to_not be_started

      schedule_heartbeat
      scheduler.stop

      expect(logs).to contains_log(
        :debug,
        "Cannot transmit heartbeat check-in `heartbeat-checkin-name` event: AppSignal is not active"
      )
    end
  end

  describe "when AppSignal is stopped" do
    it "does not transmit any events" do
      Appsignal.stop

      schedule_heartbeat

      expect(logs).to contains_log(
        :debug,
        "Cannot transmit heartbeat check-in `heartbeat-checkin-name` event: AppSignal is stopped"
      )

      scheduler.stop
    end
  end

  it "sends a heartbeat" do
    schedule_heartbeat

    stubs << stub_heartbeat_check_in_request(
      :events => [
        "identifier" => "heartbeat-checkin-name"
      ]
    )

    scheduler.stop

    expect(logs).to_not contains_log(:error)
    expect(logs).to contains_log(
      :debug,
      "Scheduling heartbeat check-in `heartbeat-checkin-name` event"
    )
  end

  it "logs an error if it fails" do
    schedule_heartbeat

    stubs << stub_heartbeat_check_in_request(
      :events => [
        "identifier" => "heartbeat-checkin-name"
      ],
      :response => { :status => 499 }
    )

    scheduler.stop

    expect(logs).to contains_log(
      :debug,
      "Scheduling heartbeat check-in `heartbeat-checkin-name` event"
    )
    expect(logs).to contains_log(
      :error,
      "Failed to transmit heartbeat check-in `heartbeat-checkin-name` event: 499 status code"
    )
  end

  describe "when the continuous option is set" do
    it "keeps sending heartbeats continuously" do
      stub_const("Appsignal::CheckIn::Scheduler::INITIAL_DEBOUNCE_SECONDS", 0.1)
      stub_const("Appsignal::CheckIn::Scheduler::BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS", 0.1)
      stub_const("Appsignal::CheckIn::HEARTBEAT_CONTINUOUS_INTERVAL_SECONDS", 0.1)

      schedule_heartbeat(:continuous => true)

      stub = stub_check_in_requests(
        # Additional requests could be made due to timing issues or when the
        # scheduler is stopped in the `after` block -- stub additional requests
        # to prevent the test from failing.
        :requests => Array.new(5) do
          [
            "identifier" => "heartbeat-checkin-name",
            "check_in_type" => "heartbeat"
          ]
        end
      )

      wait_for("the event to be transmitted") { scheduler.transmitted >= 2 }
      expect(stub.count).to be >= 2
    end
  end
end
