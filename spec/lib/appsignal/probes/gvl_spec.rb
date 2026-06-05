describe Appsignal::Probes::GvlProbe do
  let(:appsignal_mock) { AppsignalMock.new(:hostname => hostname) }
  let(:probe) { described_class.new(:appsignal => appsignal_mock, :gvl_tools => FakeGVLTools) }

  let(:hostname) { "some-host" }

  around do |example|
    real_program_name = $PROGRAM_NAME
    example.run
  ensure
    $PROGRAM_NAME = real_program_name
  end

  def gauges_for(metric)
    gauges = appsignal_mock.gauges.select do |gauge|
      gauge[0] == metric
    end

    gauges.map do |gauge|
      gauge.drop(1)
    end
  end

  # A probe wired to the real Appsignal so `set_gauge` routes through the OTel
  # metrics backend (collector mode) instead of the in-memory AppsignalMock.
  def collector_probe
    described_class.new(:appsignal => Appsignal, :gvl_tools => FakeGVLTools)
  end

  # Assert the collector-mode counterpart of the agent-mode two-entry gauge: the
  # probe emits each metric twice, once tagged with the process and once with
  # only the hostname. With the real Appsignal the hostname is the host's own,
  # so it is only checked for presence.
  def expect_dual_gauge_points(name, value, process_name:)
    snapshot = metric_snapshot(name)
    expect(snapshot).not_to be_nil
    expect(snapshot.instrument_kind).to eq(:gauge)
    expect(snapshot.data_points.size).to eq(2)
    expect(snapshot.data_points.map(&:value)).to all(eq(value))
    expect_process_tag_split(snapshot, process_name)
  end

  def expect_process_tag_split(snapshot, process_name)
    with_process = snapshot.data_points.find { |point| point.attributes.key?("process_name") }
    expect(with_process).not_to be_nil
    expect(with_process.attributes).to include(
      "process_name" => process_name,
      "process_id" => Process.pid,
      "hostname" => kind_of(String)
    )

    without_process = snapshot.data_points.find { |point| !point.attributes.key?("process_name") }
    expect(without_process).not_to be_nil
    expect(without_process.attributes.keys).to eq(["hostname"])
  end

  after { FakeGVLTools.reset }

  describe "the global timer delta gauge", :manual_start do
    def perform(probe)
      FakeGVLTools::GlobalTimer.monotonic_time = 100_000_000
      probe.call
      FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
      probe.call
    end

    it "in agent mode", :agent_mode do
      start_agent
      # The two-entry match also proves the first call emits nothing: a gauge
      # on the first call would add a third entry.
      perform(probe)

      expect(gauges_for("gvl_global_timer")).to eq [
        [200, {
          :hostname => hostname,
          :process_name => "rspec",
          :process_id => Process.pid
        }],
        [200, { :hostname => hostname }]
      ]
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      perform(collector_probe)

      # The probe emits the gauge twice: once tagged with the process, once
      # with only the hostname. Asserting exactly two points also proves the
      # first call emitted nothing.
      expect_dual_gauge_points("gvl_global_timer", 200, :process_name => "rspec")
    end
  end

  context "when the delta is negative" do
    describe "does not gauge the global timer delta" do
      def perform(probe)
        FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
        probe.call
        FakeGVLTools::GlobalTimer.monotonic_time = 0
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_global_timer")).to be_empty
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect(metric_snapshot("gvl_global_timer")).to be_nil
      end
    end
  end

  context "when the delta is zero" do
    describe "does not gauge the global timer delta" do
      def perform(probe)
        FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
        probe.call
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_global_timer")).to be_empty
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect(metric_snapshot("gvl_global_timer")).to be_nil
      end
    end
  end

  context "when the waiting threads count is enabled" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    describe "the waiting threads count gauge", :manual_start do
      def perform(probe)
        FakeGVLTools::WaitingThreads.count = 3
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_waiting_threads")).to eq [
          [3, {
            :hostname => hostname,
            :process_name => "rspec",
            :process_id => Process.pid
          }],
          [3, { :hostname => hostname }]
        ]
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect_dual_gauge_points("gvl_waiting_threads", 3, :process_name => "rspec")
      end
    end
  end

  context "when the waiting threads count is disabled" do
    before do
      FakeGVLTools::WaitingThreads.enabled = false
    end

    describe "does not gauge the waiting threads count" do
      def perform(probe)
        FakeGVLTools::WaitingThreads.count = 3
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_waiting_threads")).to be_empty
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect(metric_snapshot("gvl_waiting_threads")).to be_nil
      end
    end
  end

  context "when the process name is a custom value" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
      # Set before the probe is built: the probe reads the process name at
      # initialization, and the lazy `probe`/`collector_probe` is created in the
      # example body after this hook runs.
      $PROGRAM_NAME = "sidekiq 7.1.6 app [0 of 5 busy]"
    end

    describe "uses only the first word as the process name" do
      def perform(probe)
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_waiting_threads")).to eq [
          [0, {
            :hostname => hostname,
            :process_name => "sidekiq",
            :process_id => Process.pid
          }],
          [0, { :hostname => hostname }]
        ]
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect_dual_gauge_points("gvl_waiting_threads", 0, :process_name => "sidekiq")
      end
    end
  end

  context "when the process name is a path" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
      $PROGRAM_NAME = "/foo/folder with spaces/bin/rails"
    end

    describe "uses only the binary name as the process name" do
      def perform(probe)
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_waiting_threads")).to eq [
          [0, {
            :hostname => hostname,
            :process_name => "rails",
            :process_id => Process.pid
          }],
          [0, { :hostname => hostname }]
        ]
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect_dual_gauge_points("gvl_waiting_threads", 0, :process_name => "rails")
      end
    end
  end

  context "when the process name is an empty string" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
      $PROGRAM_NAME = ""
    end

    describe "uses [unknown process] as the process name" do
      def perform(probe)
        probe.call
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform(probe)

        expect(gauges_for("gvl_waiting_threads")).to eq [
          [0, {
            :hostname => hostname,
            :process_name => "[unknown process]",
            :process_id => Process.pid
          }],
          [0, { :hostname => hostname }]
        ]
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform(collector_probe)

        expect_dual_gauge_points("gvl_waiting_threads", 0, :process_name => "[unknown process]")
      end
    end
  end
end
