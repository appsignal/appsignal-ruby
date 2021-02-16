RSpec.describe "Puma plugin" do
  include WaitForHelper

  class MockPumaLauncher
    def events
      return @events if defined?(@events)

      @events = MockPumaEvents.new
    end
  end

  class MockPumaEvents
    def on_booted(&block)
      @on_booted = block if block_given?
      @on_booted if defined?(@on_booted)
    end
  end

  let(:probe) { MockProbe.new }
  let(:launcher) { MockPumaLauncher.new }
  before do
    module Puma
      def self.stats
      end

      def self.run
        # Capture threads running before application is preloaded
        before = Thread.list.reject { |t| t.thread_variable_get(:fork_safe) }

        # An abbreviated version of what happens in Puma::Cluster#run
        launcher = MockPumaLauncher.new
        plugin = Plugin.plugin.new
        plugin.start(launcher)
        launcher.events.on_booted.call

        # Capture any new threads running after application is preloaded.
        # Any threads created during the preloading phase will not be
        # carried over into the forked workers. Puma warns about these
        # but the minutely probe thread should only exist in the main process.
        after = Thread.list.reject { |t| t.thread_variable_get(:fork_safe) }
        $stdout.puts "! WARNING: Detected #{after.size - before.size} Thread(s) started in app boot" if after.size > before.size
      end

      class Plugin
        class << self
          attr_reader :plugin

          def create(&block)
            @plugin = Class.new(::Puma::Plugin)
            @plugin.class_eval(&block)
          end
        end
      end
    end

    Appsignal::Minutely.probes.clear
    ENV["APPSIGNAL_ENABLE_MINUTELY_PROBES"] = "true"
    Appsignal.config = project_fixture_config
    # Speed up test time
    allow(Appsignal::Minutely).to receive(:initial_wait_time).and_return(0.001)
    allow(Appsignal::Minutely).to receive(:wait_time).and_return(0.001)

    Appsignal::Minutely.probes.register :my_probe, probe
    load File.expand_path("../lib/puma/plugin/appsignal.rb", APPSIGNAL_SPEC_DIR)
  end
  after do
    Appsignal.config = nil
    Object.send :remove_const, :Puma
    Object.send :remove_const, :APPSIGNAL_PUMA_PLUGIN_LOADED
  end

  it "registers the PumaProbe" do
    expect(Appsignal::Minutely.probes[:my_probe]).to eql(probe)
    expect(Appsignal::Minutely.probes[:puma]).to be_nil
    plugin = Puma::Plugin.plugin.new
    expect(launcher.events.on_booted).to be_nil

    plugin.start(launcher)
    expect(Appsignal::Minutely.probes[:puma]).to be_nil
    expect(launcher.events.on_booted).to_not be_nil

    launcher.events.on_booted.call
    expect(Appsignal::Minutely.probes[:puma]).to eql(Appsignal::Probes::PumaProbe)

    # Minutely probes started and called
    wait_for("enough probe calls") { probe.calls >= 2 }
  end

  it "marks the PumaProbe thread as fork-safe", :not_ruby19 do
    out_stream = std_stream
    capture_stdout(out_stream) { Puma.run }

    expect(out_stream.read).not_to match(/WARNING: Detected 1 Thread/)
  end

  context "without Puma.stats" do
    before { Puma.singleton_class.send(:remove_method, :stats) }

    it "does not register the PumaProbe" do
      expect(Appsignal::Minutely.probes[:my_probe]).to eql(probe)
      expect(Appsignal::Minutely.probes[:puma]).to be_nil
      plugin = Puma::Plugin.plugin.new
      expect(launcher.events.on_booted).to be_nil

      plugin.start(launcher)
      expect(Appsignal::Minutely.probes[:puma]).to be_nil
      expect(launcher.events.on_booted).to_not be_nil

      launcher.events.on_booted.call
      expect(Appsignal::Minutely.probes[:puma]).to be_nil

      # Minutely probes started and called
      wait_for("enough probe calls") { probe.calls >= 2 }
    end
  end
end
