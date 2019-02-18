describe Appsignal::Minutely do
  before do
    Appsignal::Minutely.probes.clear
  end

  it "has a list of probes" do
    expect(Appsignal::Minutely.probes).to be_instance_of(Array)
  end

  describe ".start" do
    it "calls the probes every <wait_time>" do
      probe = double(:name => "MyProbe")
      expect(probe).to receive(:call).at_least(:twice)
      allow(Appsignal::Minutely).to receive(:wait_time).and_return(0.0001)

      Appsignal::Minutely.probes << probe
      Appsignal::Minutely.start
      sleep 0.01
    end

  end

  describe ".wait_time" do
    it "should get the time to the next minute" do
      allow_any_instance_of(Time).to receive(:sec).and_return(30)
      expect(Appsignal::Minutely.wait_time).to eq 30
    end
  end

  describe ".add_gc_probe" do
    it "adds the GC probe to the probes list" do
      expect(Appsignal::Minutely.probes).to be_empty

      Appsignal::Minutely.add_gc_probe

      expect(Appsignal::Minutely.probes.size).to eq(1)
      expect(Appsignal::Minutely.probes[0]).to be_instance_of(Appsignal::Minutely::GCProbe)
    end
  end

  describe Appsignal::Minutely::GCProbe do
    describe "#call" do
      it "collects GC metrics" do
        expect(Appsignal).to receive(:set_process_gauge).at_least(8).times

        Appsignal::Minutely::GCProbe.new.call
      end
    end
  end
end
