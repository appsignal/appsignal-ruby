# frozen_string_literal: true

module Appsignal
  module Probes
    class SidekiqProbe
      include Helpers

      class Sidekiq7Adapter
        def self.redis_info
          redis_info = nil
          ::Sidekiq.redis { |c| redis_info = c.info }
          redis_info
        end

        def self.hostname
          host = nil
          ::Sidekiq.redis do |c|
            host = c.config.host
          end
          host
        end
      end

      class Sidekiq6Adapter
        def self.redis_info
          return unless ::Sidekiq.respond_to?(:redis_info)

          ::Sidekiq.redis_info
        end

        def self.hostname
          host = nil
          ::Sidekiq.redis do |c|
            host = c.connection[:host] if c.respond_to? :connection
          end
          host
        end
      end

      # @api private
      attr_reader :config

      def self.sidekiq7_and_greater?
        Gem::Version.new(::Sidekiq::VERSION) >= Gem::Version.new("7.0.0")
      end

      # @api private
      def self.dependencies_present?
        return true if sidekiq7_and_greater?
        return unless defined?(::Redis::VERSION) # Sidekiq <= 6

        Gem::Version.new(::Redis::VERSION) >= Gem::Version.new("3.3.5")
      end

      def initialize(config = {})
        @config = config
        @cache = {}
        is_sidekiq7 = self.class.sidekiq7_and_greater?
        @adapter = is_sidekiq7 ? Sidekiq7Adapter : Sidekiq6Adapter

        config_string = " with config: #{config}" unless config.empty?
        Appsignal.internal_logger.debug("Initializing Sidekiq probe#{config_string}")
        require "sidekiq/api"
      end

      # @api private
      def call
        track_redis_info
        track_stats
        track_queues
      end

      private

      attr_reader :adapter, :cache

      def track_redis_info
        redis_info = adapter.redis_info
        return unless redis_info

        gauge "connection_count", redis_info["connected_clients"]
        gauge "memory_usage", redis_info["used_memory"]
        gauge "memory_usage_rss", redis_info["used_memory_rss"]
      end

      def track_stats
        stats = ::Sidekiq::Stats.new

        gauge "worker_count", stats.workers_size
        gauge "process_count", stats.processes_size
        gauge_delta :jobs_processed, stats.processed do |jobs_processed|
          gauge "job_count", jobs_processed, :status => :processed
        end
        gauge_delta :jobs_failed, stats.failed do |jobs_failed|
          gauge "job_count", jobs_failed, :status => :failed
        end
        gauge "job_count", stats.retry_size, :status => :retry_queue
        gauge_delta :jobs_dead, stats.dead_size do |jobs_dead|
          gauge "job_count", jobs_dead, :status => :died
        end
        gauge "job_count", stats.scheduled_size, :status => :scheduled
        gauge "job_count", stats.enqueued, :status => :enqueued
      end

      def track_queues
        ::Sidekiq::Queue.all.each do |queue|
          gauge "queue_length", queue.size, :queue => queue.name
          # Convert latency from seconds to milliseconds
          gauge "queue_latency", queue.latency * 1_000.0, :queue => queue.name
        end
      end

      # Track a gauge metric with the `sidekiq_` prefix
      def gauge(key, value, tags = {})
        return if value.nil?

        tags[:hostname] = hostname if hostname
        Appsignal.set_gauge "sidekiq_#{key}", value, tags
      end

      def hostname
        return @hostname if defined?(@hostname)

        if config.key?(:hostname)
          @hostname = config[:hostname]
          Appsignal.internal_logger.debug "Sidekiq probe: Using hostname " \
            "config option #{@hostname.inspect} as hostname"
          return @hostname
        end

        host = adapter.hostname
        Appsignal.internal_logger.debug "Sidekiq probe: Using Redis server " \
          "hostname #{host.inspect} as hostname"
        @hostname = host
      end
    end
  end
end
