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
        Queue = Struct.new(:name, :size, :latency) # rubocop:disable Lint/StructNewOverride

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
          perform
        end

        it "in collector mode", :collector_mode do
          perform

          # The agent has no in-memory metric readout, so collector mode asserts
          # that representative gauges reach the OpenTelemetry backend: a plain
          # gauge, a delta-based gauge carrying a status tag, and a per-queue
          # gauge. The agent-mode example above covers the full set of values.
          # Pull the snapshots once: each `metric_snapshots` call resets the
          # in-memory reader, so a second pull would come back empty.
          snapshots = metric_snapshots

          worker_count = snapshots.find { |snapshot| snapshot.name == "sidekiq_worker_count" }
          expect(worker_count).not_to be_nil
          expect(worker_count.instrument_kind).to eq(:gauge)
          expect(worker_count.data_points.first.value).to eq(24)
          expect(worker_count.data_points.first.attributes).to eq("hostname" => "localhost")

          job_count = snapshots.find { |snapshot| snapshot.name == "sidekiq_job_count" }
          processed = job_count.data_points.find do |point|
            point.attributes["status"] == "processed"
          end
          expect(processed.value).to eq(5)

          queue_length = snapshots.find { |snapshot| snapshot.name == "sidekiq_queue_length" }
          default_queue = queue_length.data_points.find do |point|
            point.attributes["queue"] == "default"
          end
          expect(default_queue.value).to eq(10)
        end
      end

      context "when redis info doesn't contain requested keys" do
        before { Sidekiq7Mock.redis_info_data = {} }

        it "doesn't create metrics for nil values", :agent_mode do
          expect_gauge("connection_count").never
          expect_gauge("memory_usage").never
          expect_gauge("memory_usage_rss").never
          # Call probe twice so we can calculate the delta for some gauge values
          probe.call
          probe.call
        end
      end
    end

    context "with Sidekiq 6", :agent_mode do
      before { with_sidekiq6! }

      it "logs used hostname on call once" do
        log = capture_logs { probe.call }
        expect(log).to contains_log(
          :debug,
          %(Sidekiq probe: Using Redis server hostname "localhost" as hostname)
        )
        log = capture_logs { probe.call }
        # Match more logs with incompelete message
        expect(log).to_not contains_log(:debug, %(Sidekiq probe: ))
      end

      it "collects custom metrics" do
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
        # Call probe twice so we can calculate the delta for some gauge values
        probe.call
        probe.call
      end

      context "when Sidekiq `redis_info` is not defined" do
        before do
          allow(Sidekiq).to receive(:respond_to?).with(:redis_info).and_return(false)
        end

        it "does not collect redis metrics" do
          expect_gauge("connection_count", 2).never
          expect_gauge("memory_usage", 1024).never
          expect_gauge("memory_usage_rss", 512).never
          probe.call
        end
      end
    end

    context "when hostname is configured for probe", :agent_mode do
      let(:redis_hostname) { "my_redis_server" }
      let(:probe) { described_class.new(:hostname => redis_hostname) }

      it "uses the redis hostname for the hostname tag" do
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
    end

    def expect_gauge(key, value = anything, tags = {})
      expect(Appsignal).to receive(:set_gauge)
        .with("sidekiq_#{key}", value, expected_default_tags.merge(tags))
        .and_call_original
    end
  end
end
