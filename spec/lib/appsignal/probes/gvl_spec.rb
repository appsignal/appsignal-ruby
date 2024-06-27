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

  after { FakeGVLTools.reset }

  it "gauges the global timer delta" do
    FakeGVLTools::GlobalTimer.monotonic_time = 100_000_000
    probe.call

    expect(gauges_for("gvl_global_timer")).to be_empty

    FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
    probe.call

    expect(gauges_for("gvl_global_timer")).to eq [
      [200, {
        :hostname => hostname,
        :process_name => "rspec",
        :process_id => Process.pid
      }],
      [200, { :hostname => hostname }]
    ]
  end

  context "when the delta is negative" do
    it "does not gauge the global timer delta" do
      FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
      probe.call

      expect(gauges_for("gvl_global_timer")).to be_empty

      FakeGVLTools::GlobalTimer.monotonic_time = 0
      probe.call

      expect(gauges_for("gvl_global_timer")).to be_empty
    end
  end

  context "when the delta is zero" do
    it "does not gauge the global timer delta" do
      FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
      probe.call

      expect(gauges_for("gvl_global_timer")).to be_empty

      probe.call

      expect(gauges_for("gvl_global_timer")).to be_empty
    end
  end

  context "when the waiting threads count is enabled" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    it "gauges the waiting threads count" do
      FakeGVLTools::WaitingThreads.count = 3
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to eq [
        [3, {
          :hostname => hostname,
          :process_name => "rspec",
          :process_id => Process.pid
        }],
        [3, { :hostname => hostname }]
      ]
    end
  end

  context "when the waiting threads count is disabled" do
    before do
      FakeGVLTools::WaitingThreads.enabled = false
    end

    it "does not gauge the waiting threads count" do
      FakeGVLTools::WaitingThreads.count = 3
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to be_empty
    end
  end

  context "when the process name is a custom value" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    it "uses only the first word as the process name" do
      $PROGRAM_NAME = "sidekiq 7.1.6 app [0 of 5 busy]"
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to eq [
        [0, {
          :hostname => hostname,
          :process_name => "sidekiq",
          :process_id => Process.pid
        }],
        [0, { :hostname => hostname }]
      ]
    end
  end

  context "when the process name is a path" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    it "uses only the binary name as the process name" do
      $PROGRAM_NAME = "/foo/folder with spaces/bin/rails"
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to eq [
        [0, {
          :hostname => hostname,
          :process_name => "rails",
          :process_id => Process.pid
        }],
        [0, { :hostname => hostname }]
      ]
    end
  end

  context "when the process name is an empty string" do
    before do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    it "uses [unknown process] as the process name" do
      $PROGRAM_NAME = ""
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to eq [
        [0, {
          :hostname => hostname,
          :process_name => "[unknown process]",
          :process_id => Process.pid
        }],
        [0, { :hostname => hostname }]
      ]
    end
  end
end
