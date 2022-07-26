module Appsignal
  module Probes
    class SidekiqProbe
      include Helpers

      # @api private
      attr_reader :config

      # @api private
      def self.dependencies_present?
        Gem::Version.new(::Redis::VERSION) >= Gem::Version.new("3.3.5")
      end

      def initialize(config = {})
        @config = config
        @cache = {}
        config_string = " with config: #{config}" unless config.empty?
        Appsignal.logger.debug("Initializing Sidekiq probe#{config_string}")
        require "sidekiq/api"
      end

      # @api private
      def call
        track_redis_info
        track_stats
        track_queues
      end

      private

      attr_reader :cache

      def track_redis_info
        return unless ::Sidekiq.respond_to?(:redis_info)
        redis_info = ::Sidekiq.redis_info

        gauge "connection_count", redis_info.fetch("connected_clients")
        gauge "memory_usage", redis_info.fetch("used_memory")
        gauge "memory_usage_rss", redis_info.fetch("used_memory_rss")
      end

      def track_stats
        stats = ::Sidekiq::Stats.new

        gauge "worker_count", stats.workers_size
        gauge "process_count", stats.processes_size
        jobs_processed = gauge_delta :jobs_processed, stats.processed
        if jobs_processed
          gauge "job_count", jobs_processed, :status => :processed
        end
        jobs_failed = gauge_delta :jobs_failed, stats.failed
        gauge "job_count", jobs_failed, :status => :failed if jobs_failed
        gauge "job_count", stats.retry_size, :status => :retry_queue
        jobs_dead = gauge_delta :jobs_dead, stats.dead_size
        gauge "job_count", jobs_dead, :status => :died if jobs_dead
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
        tags[:hostname] = hostname if hostname
        Appsignal.set_gauge "sidekiq_#{key}", value, tags
      end

      def hostname
        return @hostname if defined?(@hostname)
        if config.key?(:hostname)
          @hostname = config[:hostname]
          Appsignal.logger.debug "Sidekiq probe: Using hostname config " \
            "option #{@hostname.inspect} as hostname"
          return @hostname
        end

        host = nil
        ::Sidekiq.redis { |c| host = c.connection[:host] }
        Appsignal.logger.debug "Sidekiq probe: Using Redis server hostname " \
          "#{host.inspect} as hostname"
        @hostname = host
      end
    end
  end
end
