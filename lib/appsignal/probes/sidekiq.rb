module Appsignal
  module Probes
    # @api private
    class SidekiqProbe
      attr_reader :config

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
        gauge_delta :jobs_processed, "job_count", stats.processed,
          :status => :processed
        gauge_delta :jobs_failed, "job_count", stats.failed, :status => :failed
        gauge "job_count", stats.retry_size, :status => :retry_queue
        gauge_delta :jobs_dead, "job_count", stats.dead_size, :status => :died
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

      # Track the delta of two values for a gauge metric
      #
      # First call will store the data for the metric and the second call will
      # set a gauge metric with the difference. This is used for absolute
      # counter values which we want to track as gauges.
      #
      # @example
      #   gauge_delta :my_cache_key, "my_gauge", 10
      #   gauge_delta :my_cache_key, "my_gauge", 15
      #   # Creates a gauge with the value `5`
      # @see #gauge
      def gauge_delta(cache_key, key, value, tags = {})
        previous_value = cache[cache_key]
        cache[cache_key] = value
        return unless previous_value
        new_value = value - previous_value
        gauge key, new_value, tags
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
