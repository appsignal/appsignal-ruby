describe Appsignal::GarbageCollection do
  describe ".profiler" do
    before do
      # Unset the internal memoized variable to avoid state leaking
      described_class.clear_profiler!
    end

    context "when GC instrumentation is disabled" do
      it "returns the NilProfiler" do
        expect(described_class.profiler).to be_a(Appsignal::GarbageCollection::NilProfiler)
      end
    end

    context "when GC profiling is enabled" do
      before { GC::Profiler.enable }
      after { GC::Profiler.disable }

      it "returns the Profiler" do
        expect(described_class.profiler).to be_a(Appsignal::GarbageCollection::Profiler)
      end
    end
  end
end

describe Appsignal::GarbageCollection::Profiler do
  let(:internal_profiler) { FakeGCProfiler.new }
  let(:profiler) { described_class.new }

  before do
    stub_const("GC::Profiler", internal_profiler)
  end

  context "on initialization" do
    it "has a total time of 0" do
      expect(profiler.total_time).to eq(0)
    end
  end

  context "when the GC has run" do
    before { internal_profiler.total_time = 0.12345 }

    it "fetches the total time from Ruby's GC::Profiler" do
      expect(profiler.total_time).to eq(123)
    end

    it "clears Ruby's GC::Profiler afterward" do
      expect(internal_profiler).to receive(:clear)
      profiler.total_time
    end
  end

  context "when the total GC time becomes too high" do
    it "resets the total time" do
      internal_profiler.total_time = 2_147_483_647
      expect(profiler.total_time).to eq(0)
    end
  end

  context "when the GC has run multiple times" do
    it "adds all times from Ruby's GC::Profiler together" do
      2.times do
        internal_profiler.total_time = 0.12345
        profiler.total_time
      end

      expect(profiler.total_time).to eq(246)
    end
  end

  context "when in multiple threads and with a slow GC::Profiler" do
    it "does not count garbage collection times twice" do
      threads = []
      results = []
      internal_profiler.clear_delay = 0.001
      internal_profiler.total_time = 0.12345

      2.times do
        threads << Thread.new do
          profiler = Appsignal::GarbageCollection::Profiler.new
          results << profiler.total_time
        end
      end

      threads.each(&:join)
      expect(results).to eq([123, 0])
    end
  end
end

describe Appsignal::GarbageCollection::NilProfiler do
  let(:profiler) { described_class.new }

  describe "#total_time" do
    it "has a total time of 0" do
      expect(profiler.total_time).to eq(0)
    end
  end
end
