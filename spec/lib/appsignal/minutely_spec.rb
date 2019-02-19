describe Appsignal::Minutely do
  before do
    Appsignal::Minutely.probes.clear
  end

  it "has a list of probes" do
    expect(Appsignal::Minutely.probes).to be_instance_of(Array)
  end

  describe ".start" do
    class Probe
      attr_reader :calls

      def initialize
        @calls = 0
      end

      def call
        @calls += 1
      end
    end

    class BrokenProbe < Probe
      def call
        super
        raise "oh no!"
      end
    end

    let(:log_stream) { StringIO.new }
    let(:log) do
      log_stream.rewind
      log_stream.read
    end
    before do
      Appsignal.logger = Logger.new(log_stream)
      # Speed up test time
      allow(Appsignal::Minutely).to receive(:wait_time).and_return(0.001)
    end

    it "calls the probes every <wait_time>" do
      probe = Probe.new
      Appsignal::Minutely.probes << probe
      Appsignal::Minutely.start

      wait_for("enough probe calls") { probe.calls >= 2 }
      expect(log).to include("Gathering minutely metrics with 1 probe")
      expect(log).to include("Gathering minutely metrics with Probe probe")
    end

    context "with a broken probe" do
      it "logs the error and continues calling the probes every <wait_time>" do
        probe = Probe.new
        broken_probe = BrokenProbe.new
        Appsignal::Minutely.probes << probe
        Appsignal::Minutely.probes << broken_probe
        Appsignal::Minutely.start

        wait_for("enough probe calls") { probe.calls >= 2 }
        wait_for("enough broken_probe calls") { broken_probe.calls >= 2 }

        expect(log).to include("Gathering minutely metrics with 2 probes")
        expect(log).to include("Gathering minutely metrics with Probe probe")
        expect(log).to include("Gathering minutely metrics with BrokenProbe probe")
        expect(log).to include("Error in minutely thread (BrokenProbe): oh no!")
      end
    end

    # Wait for a condition to be met
    #
    # @example
    #   # Perform threaded operation
    #   wait_for("enough probe calls") { probe.calls >= 2 }
    #   # Assert on result
    #
    # @param name [String] The name of the condition to check. Used in the
    #   error when it fails.
    # @yield Assertion to check.
    # @yieldreturn [Boolean] True/False value that indicates if the condition
    #   is met.
    # @raise [StandardError] Raises error if the condition is not met after 5
    #   seconds, 5_000 tries.
    def wait_for(name)
      max_wait = 5_000
      i = 0
      while i <= max_wait
        break if yield
        i += 1
        sleep 0.001
      end

      return unless i == max_wait
      raise "Waited 5 seconds for #{name} condition, but was not met."
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
