RSpec.describe "Puma plugin" do
  let(:probe) { MockProbe.new }
  before do
    module Puma
      def self.stats
      end

      class Plugin
        class << self
          attr_reader :plugin

          def create(&block)
            @plugin = Class.new(::Puma::Plugin)
            @plugin.class_eval(&block)
          end
        end

        def in_background(&block)
          @in_background = block if block_given?
          @in_background if defined?(@in_background)
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
    expect(plugin.in_background).to be_nil

    plugin.start
    expect(Appsignal::Minutely.probes[:puma]).to be_nil
    expect(plugin.in_background).to_not be_nil

    plugin.in_background.call
    expect(Appsignal::Minutely.probes[:puma]).to eql(Appsignal::Hooks::PumaProbe)

    # Minutely probes started and called
    wait_for("enough probe calls") { probe.calls >= 2 }
  end

  context "without Puma.stats" do
    before { Puma.singleton_class.send(:remove_method, :stats) }

    it "does not register the PumaProbe" do
      expect(Appsignal::Minutely.probes[:my_probe]).to eql(probe)
      expect(Appsignal::Minutely.probes[:puma]).to be_nil
      plugin = Puma::Plugin.plugin.new
      expect(plugin.in_background).to be_nil

      plugin.start
      expect(Appsignal::Minutely.probes[:puma]).to be_nil
      expect(plugin.in_background).to_not be_nil

      plugin.in_background.call
      expect(Appsignal::Minutely.probes[:puma]).to be_nil

      # Minutely probes started and called
      wait_for("enough probe calls") { probe.calls >= 2 }
    end
  end

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
