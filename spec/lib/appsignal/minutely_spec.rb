describe Appsignal::Minutely do
  before { Appsignal::Minutely.probes.clear }

  it "returns a ProbeCollection" do
    expect(Appsignal::Minutely.probes)
      .to be_instance_of(Appsignal::Minutely::ProbeCollection)
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

    class ProbeWithoutDependency < Probe
      def self.dependencies_present?
        true
      end
    end

    class ProbeWithMissingDependency < Probe
      def self.dependencies_present?
        false
      end
    end

    class BrokenProbe < Probe
      def call
        super
        raise "oh no!"
      end
    end

    class BrokenProbeOnInitialize < Probe
      def initialize
        super
        raise "oh no initialize!"
      end

      def call
        true
      end
    end

    let(:log_stream) { StringIO.new }
    let(:log) { log_contents(log_stream) }
    before do
      Appsignal.logger = test_logger(log_stream)
      # Speed up test time
      allow(Appsignal::Minutely).to receive(:initial_wait_time).and_return(0.001)
      allow(Appsignal::Minutely).to receive(:wait_time).and_return(0.001)
    end

    context "with an instance of a class" do
      it "calls the probe every <wait_time>" do
        probe = Probe.new
        Appsignal::Minutely.probes.register :my_probe, probe
        Appsignal::Minutely.start

        wait_for("enough probe calls") { probe.calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
      end

      context "when dependency requirement is not met" do
        it "does not initialize the probe" do
          # Working probe which we can use to wait for X ticks
          working_probe = ProbeWithoutDependency.new
          Appsignal::Minutely.probes.register :probe_without_dep, working_probe

          probe = ProbeWithMissingDependency.new
          Appsignal::Minutely.probes.register :probe_with_missing_dep, probe
          Appsignal::Minutely.start

          wait_for("enough probe calls") { working_probe.calls >= 2 }
          # Only counts initialized probes
          expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
          expect(log).to contains_log :debug, "Skipping 'probe_with_missing_dep' probe, " \
            "ProbeWithMissingDependency.dependency_present? returned falsy"
        end
      end
    end

    context "with probe class" do
      it "creates an instance of the class and call that every <wait time>" do
        probe = Probe
        probe_instance = Probe.new
        expect(probe).to receive(:new).and_return(probe_instance)
        Appsignal::Minutely.probes.register :my_probe, probe
        Appsignal::Minutely.start

        wait_for("enough probe calls") { probe_instance.calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
      end

      context "when dependency requirement is not met" do
        it "does not initialize the probe" do
          # Working probe which we can use to wait for X ticks
          working_probe = ProbeWithoutDependency
          working_probe_instance = working_probe.new
          expect(working_probe).to receive(:new).and_return(working_probe_instance)
          Appsignal::Minutely.probes.register :probe_without_dep, working_probe

          probe = ProbeWithMissingDependency
          Appsignal::Minutely.probes.register :probe_with_missing_dep, probe
          Appsignal::Minutely.start

          wait_for("enough probe calls") { working_probe_instance.calls >= 2 }
          # Only counts initialized probes
          expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
          expect(log).to contains_log :debug, "Skipping 'probe_with_missing_dep' probe, " \
            "ProbeWithMissingDependency.dependency_present? returned falsy"
        end
      end

      context "when there is a problem initializing the probe" do
        it "logs an error" do
          # Working probe which we can use to wait for X ticks
          working_probe = ProbeWithoutDependency
          working_probe_instance = working_probe.new
          expect(working_probe).to receive(:new).and_return(working_probe_instance)
          Appsignal::Minutely.probes.register :probe_without_dep, working_probe

          probe = BrokenProbeOnInitialize
          Appsignal::Minutely.probes.register :broken_probe_on_initialize, probe
          Appsignal::Minutely.start

          wait_for("enough probe calls") { working_probe_instance.calls >= 2 }
          # Only counts initialized probes
          expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
          # Logs error
          expect(log).to contains_log(
            :error,
            "Error while initializing minutely probe 'broken_probe_on_initialize': " \
              "oh no initialize!"
          )
          # Start of the error backtrace as debug log
          expect(log).to contains_log :debug, File.expand_path("../../../../", __FILE__)
        end
      end
    end

    context "with a lambda" do
      it "calls the lambda every <wait time>" do
        calls = 0
        probe = lambda { calls += 1 }
        Appsignal::Minutely.probes.register :my_probe, probe
        Appsignal::Minutely.start

        wait_for("enough probe calls") { calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
      end
    end

    context "with a broken probe" do
      it "logs the error and continues calling the probes every <wait_time>" do
        probe = Probe.new
        broken_probe = BrokenProbe.new
        Appsignal::Minutely.probes.register :my_probe, probe
        Appsignal::Minutely.probes.register :broken_probe, broken_probe
        Appsignal::Minutely.start

        wait_for("enough probe calls") { probe.calls >= 2 }
        wait_for("enough broken_probe calls") { broken_probe.calls >= 2 }

        expect(log).to contains_log(:debug, "Gathering minutely metrics with 2 probes")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'broken_probe' probe")
        expect(log).to contains_log(:error, "Error in minutely probe 'broken_probe': oh no!")
        gem_path = File.expand_path("../../../../", __FILE__) # Start of backtrace
        expect(log).to contains_log(:debug, gem_path)
      end
    end

    it "ensures only one minutely probes thread is active at a time" do
      alive_thread_counter = proc { Thread.list.reject { |t| t.status == "dead" }.length }
      probe = Probe.new
      Appsignal::Minutely.probes.register :my_probe, probe
      expect do
        Appsignal::Minutely.start
      end.to change { alive_thread_counter.call }.by(1)

      wait_for("enough probe calls") { probe.calls >= 2 }
      expect(Appsignal::Minutely).to have_received(:initial_wait_time).once
      expect(Appsignal::Minutely).to have_received(:wait_time).at_least(:once)
      expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
      expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")

      # Starting twice in this spec, so expecting it more than once
      expect(Appsignal::Minutely).to have_received(:initial_wait_time).once
      expect do
        # Fetch old thread
        thread = Appsignal::Minutely.class_variable_get(:@@thread)
        Appsignal::Minutely.start
        thread && thread.join # Wait for old thread to exit
      end.to_not(change { alive_thread_counter.call })
    end
  end

  describe ".stop" do
    before do
      allow(Appsignal::Minutely).to receive(:initial_wait_time).and_return(0.001)
    end

    it "stops the minutely thread" do
      Appsignal::Minutely.start
      thread = Appsignal::Minutely.class_variable_get(:@@thread)
      expect(%w[sleep run]).to include(thread.status)
      Appsignal::Minutely.stop
      thread.join
      expect(thread.status).to eql(false)
    end

    it "clears the probe instances array" do
      Appsignal::Minutely.probes.register :my_probe, lambda {}
      Appsignal::Minutely.start
      thread = Appsignal::Minutely.class_variable_get(:@@thread)
      wait_for("probes initialized") do
        !Appsignal::Minutely.send(:probe_instances).empty?
      end
      expect(Appsignal::Minutely.send(:probe_instances)).to_not be_empty
      Appsignal::Minutely.stop
      thread.join
      expect(Appsignal::Minutely.send(:probe_instances)).to be_empty
    end
  end

  describe ".wait_time" do
    it "gets the time to the next minute" do
      time = Time.new(2019, 4, 9, 12, 0, 20)
      Timecop.freeze time do
        expect(Appsignal::Minutely.wait_time).to eq 40
      end
    end
  end

  describe ".initial_wait_time" do
    context "when started in the last 30 seconds of a minute" do
      it "waits for the number of seconds + 60" do
        time = Time.new(2019, 4, 9, 12, 0, 31)
        Timecop.freeze time do
          expect(Appsignal::Minutely.send(:initial_wait_time)).to eql(29 + 60)
        end
      end
    end

    context "when started in the first 30 seconds of a minute" do
      it "waits the remaining seconds in the minute" do
        time = Time.new(2019, 4, 9, 12, 0, 29)
        Timecop.freeze time do
          expect(Appsignal::Minutely.send(:initial_wait_time)).to eql(31)
        end
      end
    end
  end

  describe Appsignal::Minutely::ProbeCollection do
    let(:collection) { described_class.new }

    describe "#count" do
      it "returns how many probes are registered" do
        expect(collection.count).to eql(0)
        collection.register :my_probe_1, lambda {}
        expect(collection.count).to eql(1)
        collection.register :my_probe_2, lambda {}
        expect(collection.count).to eql(2)
      end
    end

    describe "#clear" do
      it "clears the list of probes" do
        collection.register :my_probe_1, lambda {}
        collection.register :my_probe_2, lambda {}
        expect(collection.count).to eql(2)
        collection.clear
        expect(collection.count).to eql(0)
      end
    end

    describe "#[]" do
      it "returns the probe for that name" do
        probe = lambda {}
        collection.register :my_probe, probe
        expect(collection[:my_probe]).to eql(probe)
      end
    end

    describe "#<<" do
      let(:out_stream) { std_stream }
      let(:output) { out_stream.read }
      let(:log_stream) { std_stream }
      let(:log) { log_contents(log_stream) }
      before { Appsignal.logger = test_logger(log_stream) }

      it "adds the probe, but prints a deprecation warning" do
        probe = lambda {}
        capture_stdout(out_stream) { collection << probe }
        deprecation_message = "Deprecated " \
          "`Appsignal::Minute.probes <<` call. Please use " \
          "`Appsignal::Minutely.probes.register` instead."
        expect(output).to include "appsignal WARNING: #{deprecation_message}"
        expect(log).to contains_log :warn, deprecation_message
        expect(collection[probe.object_id]).to eql(probe)
      end
    end

    describe "#register" do
      let(:log_stream) { std_stream }
      let(:log) { log_contents(log_stream) }
      before { Appsignal.logger = test_logger(log_stream) }

      it "adds the by key probe" do
        probe = lambda {}
        collection.register :my_probe, probe
        expect(collection[:my_probe]).to eql(probe)
      end

      context "when a probe is already registered with the same key" do
        it "logs a debug message" do
          probe = lambda {}
          collection.register :my_probe, probe
          collection.register :my_probe, probe
          expect(log).to contains_log :debug, "A probe with the name " \
            "`my_probe` is already registered. Overwriting the entry " \
            "with the new probe."
          expect(collection[:my_probe]).to eql(probe)
        end
      end
    end

    describe "#each" do
      it "loops over the registered probes" do
        probe = lambda {}
        collection.register :my_probe, probe
        list = []
        collection.each do |name, p|
          list << [name, p]
        end
        expect(list).to eql([[:my_probe, probe]])
      end
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
