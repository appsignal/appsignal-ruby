describe Appsignal::Probes do
  include WaitForHelper

  before { Appsignal::Probes.probes.clear }

  context "Minutely constant" do
    let(:err_stream) { std_stream }
    let(:stderr) { err_stream.read }

    it "returns the Probes constant calling the Minutely constant" do
      silence { expect(Appsignal::Minutely).to be(Appsignal::Probes) }
    end

    it "prints a deprecation warning to STDERR" do
      capture_std_streams(std_stream, err_stream) do
        expect(Appsignal::Minutely).to be(Appsignal::Probes)
      end

      expect(stderr)
        .to include("appsignal WARNING: The constant Appsignal::Minutely has been deprecated.")
    end

    it "logs a warning" do
      logs =
        capture_logs do
          silence do
            expect(Appsignal::Minutely).to be(Appsignal::Probes)
          end
        end

      expect(logs).to contains_log(
        :warn,
        "The constant Appsignal::Minutely has been deprecated."
      )
    end
  end

  it "returns a ProbeCollection" do
    expect(Appsignal::Probes.probes)
      .to be_instance_of(Appsignal::Probes::ProbeCollection)
  end

  describe ".start" do
    class ProbeWithoutDependency < MockProbe
      def self.dependencies_present?
        true
      end
    end

    class ProbeWithMissingDependency < MockProbe
      def self.dependencies_present?
        false
      end
    end

    class BrokenProbe < MockProbe
      def call
        super
        raise "oh no!"
      end
    end

    class BrokenProbeOnInitialize < MockProbe
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
      Appsignal.internal_logger = test_logger(log_stream)
      speed_up_tests!
    end

    describe ".started?" do
      it "returns true when the probes thread has been started" do
        expect(Appsignal::Probes.started?).to be_falsy
        Appsignal::Probes.register :my_probe, lambda {}
        Appsignal::Probes.start
        expect(Appsignal::Probes.started?).to be_truthy
      end

      it "returns false when the probes thread has been stopped" do
        Appsignal::Probes.register :my_probe, lambda {}
        Appsignal::Probes.start
        expect(Appsignal::Probes.started?).to be_truthy
        Appsignal::Probes.stop
        expect(Appsignal::Probes.started?).to be_falsy
      end
    end

    context "with an instance of a class" do
      it "calls the probe every <wait_time>" do
        probe = MockProbe.new
        Appsignal::Probes.register :my_probe, probe
        Appsignal::Probes.start

        wait_for("enough probe calls") { probe.calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
      end

      context "when dependency requirement is not met" do
        it "does not initialize the probe" do
          # Working probe which we can use to wait for X ticks
          working_probe = ProbeWithoutDependency.new
          Appsignal::Probes.register :probe_without_dep, working_probe

          probe = ProbeWithMissingDependency.new
          Appsignal::Probes.register :probe_with_missing_dep, probe
          Appsignal::Probes.start

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
        probe = MockProbe
        probe_instance = MockProbe.new
        expect(probe).to receive(:new).and_return(probe_instance)
        Appsignal::Probes.register :my_probe, probe
        Appsignal::Probes.start

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
          Appsignal::Probes.register :probe_without_dep, working_probe

          probe = ProbeWithMissingDependency
          Appsignal::Probes.register :probe_with_missing_dep, probe
          Appsignal::Probes.start

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
          Appsignal::Probes.register :probe_without_dep, working_probe

          probe = BrokenProbeOnInitialize
          Appsignal::Probes.register :broken_probe_on_initialize, probe
          Appsignal::Probes.start

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
          expect(log).to contains_log :debug, File.expand_path("../../..", __dir__)
        end
      end
    end

    context "with a lambda" do
      it "calls the lambda every <wait time>" do
        calls = 0
        probe = lambda { calls += 1 }
        Appsignal::Probes.register :my_probe, probe
        Appsignal::Probes.start

        wait_for("enough probe calls") { calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
      end
    end

    context "with a broken probe" do
      it "logs the error and continues calling the probes every <wait_time>" do
        probe = MockProbe.new
        broken_probe = BrokenProbe.new
        Appsignal::Probes.register :my_probe, probe
        Appsignal::Probes.register :broken_probe, broken_probe
        Appsignal::Probes.start

        wait_for("enough probe calls") { probe.calls >= 2 }
        wait_for("enough broken_probe calls") { broken_probe.calls >= 2 }

        expect(log).to contains_log(:debug, "Gathering minutely metrics with 2 probes")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'broken_probe' probe")
        expect(log).to contains_log(:error, "Error in minutely probe 'broken_probe': oh no!")
        gem_path = File.expand_path("../../..", __dir__) # Start of backtrace
        expect(log).to contains_log(:debug, gem_path)
      end
    end

    context "with a probe that takes 60 seconds" do
      it "logs an error and continues calling the probes every <wait_time>" do
        stub_const("Appsignal::Probes::ITERATION_IN_SECONDS", 0.2)
        calls = 0
        probe = lambda do
          calls += 1
          sleep 0.2
        end
        Appsignal::Probes.register :my_probe, probe
        Appsignal::Probes.register :other_probe, lambda {}
        Appsignal::Probes.start

        wait_for("enough probe calls") { calls >= 2 }

        expect(log).to contains_log(
          :error,
          "The minutely probes took more than 60 seconds. " \
            "The probes should not take this long as metrics will not " \
            "be accurately reported."
        )
      end
    end

    it "ensures only one minutely probes thread is active at a time" do
      alive_thread_counter = proc { Thread.list.reject { |t| t.status == "dead" }.length }
      probe = MockProbe.new
      Appsignal::Probes.register :my_probe, probe
      expect do
        Appsignal::Probes.start
      end.to change { alive_thread_counter.call }.by(1)

      wait_for("enough probe calls") { probe.calls >= 2 }
      expect(Appsignal::Probes).to have_received(:initial_wait_time).once
      expect(Appsignal::Probes).to have_received(:wait_time).at_least(:once)
      expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
      expect(log).to contains_log(:debug, "Gathering minutely metrics with 'my_probe' probe")

      # Starting twice in this spec, so expecting it more than once
      expect(Appsignal::Probes).to have_received(:initial_wait_time).once
      expect do
        # Fetch old thread
        thread = Appsignal::Probes.instance_variable_get(:@thread)
        Appsignal::Probes.start
        thread&.join # Wait for old thread to exit
      end.to_not(change { alive_thread_counter.call })
    end

    context "with thread already started" do
      it "auto starts probes added after the thread is started" do
        Appsignal::Probes.start
        wait_for("Probes thread to start") { Appsignal::Probes.started? }

        calls = 0
        probe = lambda { calls += 1 }
        Appsignal::Probes.register :late_probe, probe

        wait_for("enough probe calls") { calls >= 2 }
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 1 probe")
        expect(log).to contains_log(:debug, "Gathering minutely metrics with 'late_probe' probe")
      end
    end
  end

  describe ".unregister" do
    let(:log_stream) { StringIO.new }
    let(:log) { log_contents(log_stream) }
    before do
      Appsignal.internal_logger = test_logger(log_stream)
      speed_up_tests!
    end

    it "does not call the initialized probe after unregistering" do
      probe1_calls = 0
      probe2_calls = 0
      probe1 = lambda { probe1_calls += 1 }
      probe2 = lambda { probe2_calls += 1 }
      Appsignal::Probes.register :probe1, probe1
      Appsignal::Probes.register :probe2, probe2
      Appsignal::Probes.start
      wait_for("enough probe1 calls") { probe1_calls >= 2 }
      wait_for("enough probe2 calls") { probe2_calls >= 2 }

      Appsignal::Probes.unregister :probe2
      probe1_calls = 0
      probe2_calls = 0
      # Check the probe 1 calls to make sure the probes have been called before
      # testing if the unregistered probe has not been called
      wait_for("enough probe1 calls") { probe1_calls >= 2 }
      expect(probe2_calls).to eq(0)
    end
  end

  describe ".stop" do
    before do
      speed_up_tests!
    end

    it "stops the minutely thread" do
      Appsignal::Probes.start
      thread = Appsignal::Probes.instance_variable_get(:@thread)
      expect(%w[sleep run]).to include(thread.status)
      Appsignal::Probes.stop
      thread.join
      expect(thread.status).to eql(false)
    end

    it "clears the probe instances array" do
      Appsignal::Probes.register :my_probe, lambda {}
      Appsignal::Probes.start
      thread = Appsignal::Probes.instance_variable_get(:@thread)
      wait_for("probes initialized") do
        !Appsignal::Probes.send(:probe_instances).empty?
      end
      expect(Appsignal::Probes.send(:probe_instances)).to_not be_empty
      Appsignal::Probes.stop
      thread.join
      expect(Appsignal::Probes.send(:probe_instances)).to be_empty
    end
  end

  describe ".wait_time" do
    it "gets the time to the next minute" do
      time = Time.new(2019, 4, 9, 12, 0, 20)
      Timecop.freeze time do
        expect(Appsignal::Probes.wait_time).to eq 40
      end
    end
  end

  describe ".initial_wait_time" do
    context "when started in the last 30 seconds of a minute" do
      it "waits for the number of seconds + 60" do
        time = Time.new(2019, 4, 9, 12, 0, 31)
        Timecop.freeze time do
          expect(Appsignal::Probes.send(:initial_wait_time)).to eql(29 + 60)
        end
      end
    end

    context "when started in the first 30 seconds of a minute" do
      it "waits the remaining seconds in the minute" do
        time = Time.new(2019, 4, 9, 12, 0, 29)
        Timecop.freeze time do
          expect(Appsignal::Probes.send(:initial_wait_time)).to eql(31)
        end
      end
    end
  end

  describe Appsignal::Probes::ProbeCollection do
    let(:collection) { described_class.new }

    describe "#count" do
      it "returns how many probes are registered" do
        expect(collection.count).to eql(0)
        collection.internal_register :my_probe_1, lambda {}
        expect(collection.count).to eql(1)
        collection.internal_register :my_probe_2, lambda {}
        expect(collection.count).to eql(2)
      end
    end

    describe "#clear" do
      it "clears the list of probes" do
        collection.internal_register :my_probe_1, lambda {}
        collection.internal_register :my_probe_2, lambda {}
        expect(collection.count).to eql(2)
        collection.clear
        expect(collection.count).to eql(0)
      end
    end

    describe "#[]" do
      it "returns the probe for that name" do
        probe = lambda {}
        collection.internal_register :my_probe, probe
        expect(collection[:my_probe]).to eql(probe)
      end
    end

    describe "#register" do
      it "adds the probe by key" do
        expect(Appsignal::Probes).to receive(:probes).and_return(collection)

        probe = lambda {}
        silence { collection.register :my_probe, probe }
        expect(collection[:my_probe]).to eql(probe)
      end

      context "logger" do
        let(:log_stream) { std_stream }
        let(:log) { log_contents(log_stream) }

        around { |example| use_logger_with(log_stream) { example.run } }
        it "logs a deprecation message" do
          silence { collection.register :my_probe, lambda {} }
          expect(log).to contains_log :warn,
            "The method 'Appsignal::Probes.probes.register' is deprecated. " \
              "Use 'Appsignal::Probes.register' instead."
        end
      end

      context "stderr" do
        let(:err_stream) { std_stream }
        let(:stderr) { err_stream.read }

        it "prints a deprecation warning" do
          capture_std_streams(std_stream, err_stream) do
            collection.register :my_probe, lambda {}
          end
          deprecation_message =
            "The method 'Appsignal::Probes.probes.register' is deprecated. " \
              "Use 'Appsignal::Probes.register' instead."
          expect(stderr).to include("appsignal WARNING: #{deprecation_message}")
        end
      end
    end

    describe "#internal_register" do
      let(:log_stream) { std_stream }
      let(:log) { log_contents(log_stream) }
      before { Appsignal.internal_logger = test_logger(log_stream) }

      it "adds the probe by key" do
        probe = lambda {}
        collection.internal_register :my_probe, probe
        expect(collection[:my_probe]).to eql(probe)
      end

      context "when a probe is already registered with the same key" do
        it "logs a debug message" do
          probe = lambda {}
          collection.internal_register :my_probe, probe
          collection.internal_register :my_probe, probe
          expect(log).to contains_log :debug, "A probe with the name " \
            "`my_probe` is already registered. Overwriting the entry " \
            "with the new probe."
          expect(collection[:my_probe]).to eql(probe)
        end
      end
    end

    describe "#unregister" do
      it "removes the probe from the collection" do
        expect(Appsignal::Probes).to receive(:probes).and_return(collection)

        probe = lambda {}
        silence { collection.register :my_probe, probe }
        expect(collection[:my_probe]).to eql(probe)

        silence { collection.unregister :my_probe }
        expect(collection[:my_probe]).to be_nil
      end
    end

    describe "#each" do
      it "loops over the registered probes" do
        probe = lambda {}
        collection.internal_register :my_probe, probe
        list = []
        collection.each do |name, p| # rubocop:disable Style/MapIntoArray
          list << [name, p]
        end
        expect(list).to eql([[:my_probe, probe]])
      end
    end
  end

  # Speed up test time by decreasing wait times in the probes mechanism
  def speed_up_tests!
    allow(Appsignal::Probes).to receive(:initial_wait_time).and_return(0.001)
    allow(Appsignal::Probes).to receive(:wait_time).and_return(0.001)
  end
end
