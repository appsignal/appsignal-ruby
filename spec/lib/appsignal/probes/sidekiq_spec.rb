require "appsignal/probes/sidekiq"

describe Appsignal::Probes::SidekiqProbe do
  describe "#call" do
    let(:probe) { described_class.new }
    let(:redis_hostname) { "localhost" }
    let(:expected_default_tags) { { :hostname => "localhost" } }
    # `start_agent` is supplied by the `:agent_mode`/`:collector_mode` contexts
    # on each example, not here -- a hardcoded `start_agent` would boot the agent
    # in agent mode and clobber collector mode's collector-endpoint setup.
    before do
      # The probe will `require "sidekiq/api"` on initialize, which
      # as of 8.0.8 expects the `Sidekiq` module to provide a `loader`
      # method that responds to `run_load_hooks`.
      class SidekiqLoader
        class << self
          def run_load_hooks(name)
          end
        end
      end

      class SidekiqStats
        class << self
          attr_reader :calls

          def count_call
            @calls ||= -1
            @calls += 1
          end
        end

        def workers_size
          # First method called, so count it towards a call
          self.class.count_call
          24
        end

        def processes_size
          25
        end

        # Return two different values for two separate calls.
        # This allows us to test the delta of the value send as a gauge.
        def processed
          [10, 15][self.class.calls]
        end

        # Return two different values for two separate calls.
        # This allows us to test the delta of the value send as a gauge.
        def failed
          [10, 13][self.class.calls]
        end

        def retry_size
          12
        end

        # Return two different values for two separate calls.
        # This allows us to test the delta of the value send as a gauge.
        def dead_size
          [10, 12][self.class.calls]
        end

        def scheduled_size
          14
        end

        def enqueued
          15
        end
      end

      class SidekiqQueue
        Queue = Struct.new(:name, :size, :latency)

        def self.all
          [
            Queue.new("default", 10, 12),
            Queue.new("critical", 1, 2)
          ]
        end
      end

      module Sidekiq7Mock
        VERSION = "7.0.0".freeze

        def self.redis_info_data=(info)
          @redis_info_data = info
        end

        def self.redis_info_data
          return @redis_info_data if defined?(@redis_info_data)

          {
            "connected_clients" => 2,
            "used_memory" => 1024,
            "used_memory_rss" => 512
          }
        end

        def self.redis
          yield Client.new
        end

        class Client
          def config
            Config.new
          end

          def info
            Sidekiq7Mock.redis_info_data
          end
        end

        class Config
          def host
            "localhost"
          end
        end

        def self.loader
          SidekiqLoader
        end

        Stats = ::SidekiqStats
        Queue = ::SidekiqQueue
      end

      module Sidekiq6Mock
        VERSION = "6.9.9".freeze

        def self.redis_info
          {
            "connected_clients" => 2,
            "used_memory" => 1024,
            "used_memory_rss" => 512
          }
        end

        def self.redis
          yield Client.new
        end

        class Client
          def connection
            { :host => "localhost" }
          end
        end

        def self.loader
          SidekiqLoader
        end

        Stats = ::SidekiqStats
        Queue = ::SidekiqQueue
      end
    end
    after do
      Object.send(:remove_const, :SidekiqStats)
      Object.send(:remove_const, :SidekiqQueue)
      Object.send(:remove_const, :Sidekiq6Mock)
      Object.send(:remove_const, :Sidekiq7Mock)
    end

    def with_sidekiq7!
      stub_const("Sidekiq", Sidekiq7Mock)
    end
    # Version not relevant, but requires any version for tests
    alias_method :with_sidekiq!, :with_sidekiq7!

    def with_sidekiq6!
      stub_const("Sidekiq", Sidekiq6Mock)
    end

    describe ".dependencies_present?" do
      context "when Sidekiq 7" do
        before { with_sidekiq7! }

        it "starts the probe" do
          expect(described_class.dependencies_present?).to be_truthy
        end
      end

      context "when Sidekiq 6" do
        before do
          with_sidekiq6!
          stub_const("Redis::VERSION", version)
        end

        context "when Redis version is < 3.3.5" do
          let(:version) { "3.3.4" }

          it "does not start probe" do
            expect(described_class.dependencies_present?).to be_falsy
          end
        end

        context "when Redis version is >= 3.3.5" do
          let(:version) { "3.3.5" }

          it "starts the probe" do
            expect(described_class.dependencies_present?).to be_truthy
          end
        end
      end
    end

    it "loads Sidekiq::API", :agent_mode do
      with_sidekiq!
      # Hide the Sidekiq constant if it was already loaded. It will be
      # redefined by loading "sidekiq/api" in the probe.
      hide_const "Sidekiq::Stats"

      expect(defined?(Sidekiq::Stats)).to be_falsy
      probe
      expect(defined?(Sidekiq::Stats)).to be_truthy
    end

    it "logs config on initialize", :agent_mode do
      with_sidekiq!
      log = capture_logs { probe }
      expect(log).to contains_log(:debug, "Initializing Sidekiq probe\n")
    end

    context "with Sidekiq 7" do
      before { with_sidekiq7! }

      it "logs used hostname on call once", :agent_mode do
        log = capture_logs { probe.call }
        expect(log).to contains_log(
          :debug,
          %(Sidekiq probe: Using Redis server hostname "localhost" as hostname)
        )
        log = capture_logs { probe.call }
        # Match more logs with incompelete message
        expect(log).to_not contains_log(:debug, %(Sidekiq probe: ))
      end

      describe "collecting custom metrics" do
        # Call the probe twice so the delta-based gauges report a value.
        def perform
          probe.call
          probe.call
        end

        it "in agent mode", :agent_mode do
          expect_all_custom_gauges
          perform
        end

        it "in collector mode", :collector_mode do
          perform
          expect_all_custom_gauge_snapshots
        end
      end

      context "when redis info doesn't contain requested keys" do
        before { Sidekiq7Mock.redis_info_data = {} }

        describe "the redis info gauges" do
          # Call probe twice so we can calculate the delta for some gauge values.
          def perform
            probe.call
            probe.call
          end

          it "doesn't create metrics for nil values in agent mode", :agent_mode do
            expect_gauge("connection_count").never
            expect_gauge("memory_usage").never
            expect_gauge("memory_usage_rss").never
            perform
          end

          it "doesn't create metrics for nil values in collector mode", :collector_mode do
            perform
            names = metric_snapshots.map(&:name)
            expect(names).not_to include("sidekiq_connection_count")
            expect(names).not_to include("sidekiq_memory_usage")
            expect(names).not_to include("sidekiq_memory_usage_rss")
          end
        end
      end
    end

    context "with Sidekiq 6" do
      before { with_sidekiq6! }

      it "logs used hostname on call once", :agent_mode do
        log = capture_logs { probe.call }
        expect(log).to contains_log(
          :debug,
          %(Sidekiq probe: Using Redis server hostname "localhost" as hostname)
        )
        log = capture_logs { probe.call }
        # Match more logs with incompelete message
        expect(log).to_not contains_log(:debug, %(Sidekiq probe: ))
      end

      describe "collecting custom metrics" do
        # Call the probe twice so the delta-based gauges report a value.
        def perform
          probe.call
          probe.call
        end

        it "in agent mode", :agent_mode do
          expect_all_custom_gauges
          perform
        end

        it "in collector mode", :collector_mode do
          perform
          expect_all_custom_gauge_snapshots
        end
      end

      context "when Sidekiq `redis_info` is not defined" do
        before do
          allow(Sidekiq).to receive(:respond_to?).with(:redis_info).and_return(false)
        end

        describe "the redis info gauges" do
          it "does not collect redis metrics in agent mode", :agent_mode do
            expect_gauge("connection_count", 2).never
            expect_gauge("memory_usage", 1024).never
            expect_gauge("memory_usage_rss", 512).never
            probe.call
          end

          it "does not collect redis metrics in collector mode", :collector_mode do
            probe.call
            names = metric_snapshots.map(&:name)
            expect(names).not_to include("sidekiq_connection_count")
            expect(names).not_to include("sidekiq_memory_usage")
            expect(names).not_to include("sidekiq_memory_usage_rss")
          end
        end
      end
    end

    context "when hostname is configured for probe" do
      let(:redis_hostname) { "my_redis_server" }
      let(:probe) { described_class.new(:hostname => redis_hostname) }

      it "uses the redis hostname for the hostname tag", :agent_mode do
        with_sidekiq!

        allow(Appsignal).to receive(:set_gauge).and_call_original
        log = capture_logs { probe }
        expect(log).to contains_log(
          :debug,
          %(Initializing Sidekiq probe with config: hostname: "#{redis_hostname}")
        )
        log = capture_logs { probe.call }
        expect(log).to contains_log(
          :debug,
          "Sidekiq probe: Using hostname config option #{redis_hostname.inspect} as hostname"
        )
        expect(Appsignal).to have_received(:set_gauge)
          .with(anything, anything, :hostname => redis_hostname).at_least(:once)
      end

      it "tags the emitted gauges with the configured hostname", :collector_mode do
        with_sidekiq!

        probe.call

        snapshot = metric_snapshot("sidekiq_worker_count")
        expect(snapshot).not_to be_nil
        expect(snapshot.data_points.first.attributes).to eq("hostname" => redis_hostname)
      end
    end

    def expect_gauge(key, value = anything, tags = {})
      expect(Appsignal).to receive(:set_gauge)
        .with("sidekiq_#{key}", value, expected_default_tags.merge(tags))
        .and_call_original
    end

    # The full set of gauges the probe emits over two `#call`s, asserted in
    # agent mode via `set_gauge` message expectations. Delta-based gauges
    # (processed/failed/died job counts) only report on the second call, so
    # they are expected once; every other gauge is expected on both calls.
    def expect_all_custom_gauges
      expect_gauge("worker_count", 24).twice
      expect_gauge("process_count", 25).twice
      expect_gauge("connection_count", 2).twice
      expect_gauge("memory_usage", 1024).twice
      expect_gauge("memory_usage_rss", 512).twice
      expect_gauge("job_count", 5, :status => :processed) # Gauge delta
      expect_gauge("job_count", 3, :status => :failed) # Gauge delta
      expect_gauge("job_count", 12, :status => :retry_queue).twice
      expect_gauge("job_count", 2, :status => :died) # Gauge delta
      expect_gauge("job_count", 14, :status => :scheduled).twice
      expect_gauge("job_count", 15, :status => :enqueued).twice
      expect_gauge("queue_length", 10, :queue => "default").twice
      expect_gauge("queue_latency", 12_000, :queue => "default").twice
      expect_gauge("queue_length", 1, :queue => "critical").twice
      expect_gauge("queue_latency", 2_000, :queue => "critical").twice
    end

    # The collector-mode counterpart of `expect_all_custom_gauges`: the agent
    # has no in-memory readout, so here we read the same gauges back off the
    # OpenTelemetry exporter and assert each value AND its attributes. A gauge
    # holds its last recorded value, so the values match the agent-mode deltas.
    # Each row is [metric short name, extra attributes, expected value]. A gauge
    # holds its last recorded value, so the delta-based job counts
    # (processed/failed/died) match the agent-mode deltas.
    EXPECTED_CUSTOM_GAUGES = [
      ["worker_count", {}, 24],
      ["process_count", {}, 25],
      ["connection_count", {}, 2],
      ["memory_usage", {}, 1024],
      ["memory_usage_rss", {}, 512],
      ["job_count", { "status" => "processed" }, 5],
      ["job_count", { "status" => "failed" }, 3],
      ["job_count", { "status" => "retry_queue" }, 12],
      ["job_count", { "status" => "died" }, 2],
      ["job_count", { "status" => "scheduled" }, 14],
      ["job_count", { "status" => "enqueued" }, 15],
      ["queue_length", { "queue" => "default" }, 10],
      ["queue_latency", { "queue" => "default" }, 12_000],
      ["queue_length", { "queue" => "critical" }, 1],
      ["queue_latency", { "queue" => "critical" }, 2_000]
    ].freeze

    def expect_all_custom_gauge_snapshots
      # `metric_snapshots` resets the reader on each call, so pull once.
      snapshots = metric_snapshots

      EXPECTED_CUSTOM_GAUGES.each do |name, extra_attributes, value|
        snapshot = snapshots.find { |s| s.name == "sidekiq_#{name}" }
        expect(snapshot).not_to(be_nil, "expected a sidekiq_#{name} snapshot")
        expect(snapshot.instrument_kind).to eq(:gauge)
        expected_attributes = { "hostname" => "localhost" }.merge(extra_attributes)
        point = snapshot.data_points.find { |p| p.attributes == expected_attributes }
        expect(point).not_to(be_nil, "expected sidekiq_#{name} point with #{expected_attributes}")
        expect(point.value).to eq(value)
      end
    end
  end
end
