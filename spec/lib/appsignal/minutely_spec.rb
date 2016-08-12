require 'spec_helper'

describe Appsignal::Minutely do
  before do
    Appsignal::Minutely.probes.clear
  end

  it "should have a list of probes" do
    expect( Appsignal::Minutely.probes ).to be_instance_of(Array)
  end

  describe ".start" do
    it "should call the probes periodically" do
      probe = double
      expect( probe ).to receive(:call).at_least(:twice)
      Appsignal::Minutely.probes << probe
      Appsignal::Minutely.stub(:wait_time => 0.1)

      Appsignal::Minutely.start

      sleep 0.5
    end
  end

  describe ".wait_time" do
    it "should get the time to the next minute" do
      Time.any_instance.stub(:sec => 30)
      expect( Appsignal::Minutely.wait_time ).to eq 30
    end
  end

  describe ".add_gc_probe" do
    it "should add the gc probe to the list" do
      expect( Appsignal::Minutely.probes ).to be_empty

      Appsignal::Minutely.add_gc_probe

      expect( Appsignal::Minutely.probes ).to have(1).item
      expect( Appsignal::Minutely.probes[0] ).to be_instance_of(Appsignal::Minutely::GCProbe)
    end
  end

  describe Appsignal::Minutely::GCProbe do
    describe "#call" do
      it "should collect GC metrics" do
        expect(Appsignal).to receive(:set_process_gauge).with('gc.count', kind_of(Integer)).once
        expect(Appsignal).to receive(:set_process_gauge).with('gc.heap_allocated_pages', kind_of(Integer)).once
        expect(Appsignal).to receive(:set_process_gauge).at_least(10).times

        Appsignal::Minutely::GCProbe.new.call
      end
    end
  end
end
