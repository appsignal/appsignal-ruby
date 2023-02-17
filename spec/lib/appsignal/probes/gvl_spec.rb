describe Appsignal::Probes::GvlProbe do
  let(:appsignal_mock) { AppsignalMock.new(:hostname => hostname) }
  let(:probe) { described_class.new(:appsignal => appsignal_mock, :gvl_tools => FakeGVLTools) }

  let(:hostname) { "some-host" }

  after(:each) { FakeGVLTools.reset }

  context "with global timer enabled" do
    before(:each) { FakeGVLTools::GlobalTimer.enabled = true }

    it "gauges the global timer delta" do
      FakeGVLTools::GlobalTimer.monotonic_time = 100_000_000
      probe.call

      expect(appsignal_mock.gauges).to be_empty

      FakeGVLTools::GlobalTimer.monotonic_time = 300_000_000
      probe.call

      expect(appsignal_mock.gauges).to eq [
        ["gvl_global_timer", 200, { :hostname => hostname }]
      ]
    end
  end

  context "with waiting threads enabled" do
    before(:each) { FakeGVLTools::WaitingThreads.enabled = true }

    it "gauges the waiting threads count" do
      FakeGVLTools::WaitingThreads.count = 3
      probe.call

      expect(appsignal_mock.gauges).to eq [
        ["gvl_waiting_threads", 3, { :hostname => hostname }]
      ]
    end
  end
end
