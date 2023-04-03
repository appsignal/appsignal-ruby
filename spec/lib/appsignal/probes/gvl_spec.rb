describe Appsignal::Probes::GvlProbe do
  let(:appsignal_mock) { AppsignalMock.new(:hostname => hostname) }
  let(:probe) { described_class.new(:appsignal => appsignal_mock, :gvl_tools => FakeGVLTools) }

  let(:hostname) { "some-host" }

  def gauges_for(metric)
    gauges = appsignal_mock.gauges.select do |gauge|
      gauge[0] == metric
    end

    gauges.map do |gauge|
      gauge.drop(1)
    end
  end

  after(:each) { FakeGVLTools.reset }

  it "gauges the global timer delta" do
    FakeGVLTools::GlobalTimer.monotonic_time = 100_000_000
    probe.call

    expect(gauges_for("gvl_global_timer")).to be_empty

    FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
    probe.call

    expect(gauges_for("gvl_global_timer")).to eq [
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
    before(:each) do
      FakeGVLTools::WaitingThreads.enabled = true
    end

    it "gauges the waiting threads count" do
      FakeGVLTools::WaitingThreads.count = 3
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to eq [
        [3, { :hostname => hostname }]
      ]
    end
  end

  context "when the waiting threads count is disabled" do
    before(:each) do
      FakeGVLTools::WaitingThreads.enabled = false
    end

    it "does not gauge the waiting threads count" do
      FakeGVLTools::WaitingThreads.count = 3
      probe.call

      expect(gauges_for("gvl_waiting_threads")).to be_empty
    end
  end
end
