require 'spec_helper'
require_relative '../../support/mocks/fake_gc_profiler'

describe Appsignal::GarbageCollectionProfiler do
  let(:internal_profiler) { FakeGCProfiler.new }

  before do
    allow_any_instance_of(Appsignal::GarbageCollectionProfiler)
      .to receive(:internal_profiler)
      .and_return(internal_profiler)
  end

  it "should have a total time of 0" do
    expect(Appsignal::GarbageCollectionProfiler.new.total_time).to eq(0)
  end

  describe "after a GC run" do
    before do
      internal_profiler.total_time = 0.12345
      @profiler = Appsignal::GarbageCollectionProfiler.new
    end

    it "should take the total time from Ruby's GC::Profiler" do
      expect(@profiler.total_time).to eq(123)
    end

    it "should clear Ruby's GC::Profiler" do
      expect(internal_profiler).to receive(:clear)
      @profiler.total_time
    end
  end

  describe "when the total GC time becomes too high" do
    it "should reset" do
      profiler = Appsignal::GarbageCollectionProfiler.new
        internal_profiler.total_time = 2_147_483_647
        expect(profiler.total_time).to eq(0)
    end
  end

  describe "after multiple GC runs" do
    it "should add all times from Ruby's GC::Profiler together" do
      profiler = Appsignal::GarbageCollectionProfiler.new

      2.times do
        internal_profiler.total_time = 0.12345
        profiler.total_time
      end

      expect(profiler.total_time).to eq(246)
    end
  end

  describe "in multiple threads, with a slow GC::Profiler" do
    it "should not count garbage collection times twice" do
      threads, results = [], []
      internal_profiler.clear_delay = 0.001
      internal_profiler.total_time = 0.12345

      2.times do
        threads << Thread.new do
          profiler = Appsignal::GarbageCollectionProfiler.new
          results << profiler.total_time
        end
      end

      threads.each(&:join)
      expect(results).to eq([123, 0])
    end
  end
end
