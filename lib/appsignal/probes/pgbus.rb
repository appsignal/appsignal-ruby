# frozen_string_literal: true

module Appsignal
  module Probes
    # Minutely probe that reports Pgbus queue depths, process counts,
    # dead letter queue sizes, and stream connection estimates.
    #
    # Requires Pgbus to expose a Web::DataSource-compatible interface.
    # The probe gracefully skips metrics when the underlying data source
    # methods are unavailable or raise errors.
    #
    # @!visibility private
    class PgbusProbe
      include Helpers

      def initialize(config = {})
        @config = config
        Appsignal.internal_logger.debug("Initializing Pgbus probe")
      end

      def call
        return unless data_source

        track_queues
        track_processes
        track_summary
        track_streams
      end

      private

      def data_source
        return @data_source if defined?(@data_source)

        @data_source =
          if defined?(::Pgbus::Web::DataSource)
            ::Pgbus::Web::DataSource.new
          end
      end

      def track_queues
        queues = data_source.queues_with_metrics
        queues.each do |queue|
          gauge "queue_depth", queue[:queue_length], :queue => queue[:name]
          gauge "queue_visible_depth", queue[:queue_visible_length], :queue => queue[:name]
          if queue[:oldest_msg_age_sec]
            gauge "queue_oldest_message_age_seconds", queue[:oldest_msg_age_sec],
              :queue => queue[:name]
          end
        end
      rescue StandardError => e
        Appsignal.internal_logger.debug("Pgbus probe: queue metrics failed: #{e.message}")
      end

      def track_processes
        count = data_source.processes.count
        gauge "active_processes", count
      rescue StandardError => e
        Appsignal.internal_logger.debug("Pgbus probe: process metrics failed: #{e.message}")
      end

      def track_summary
        stats = data_source.summary_stats
        gauge "dlq_depth", stats[:dlq_depth]
        gauge "failed_events_total", stats[:failed_count]
      rescue StandardError => e
        Appsignal.internal_logger.debug("Pgbus probe: summary metrics failed: #{e.message}")
      end

      def track_streams
        return unless data_source.respond_to?(:stream_stats_available?) &&
          data_source.stream_stats_available?

        summary = data_source.stream_stats_summary
        gauge "stream_broadcasts", summary[:broadcasts]
        gauge "stream_active_connections", summary[:active_estimate]
        gauge "stream_avg_fanout", summary[:avg_fanout]
      rescue StandardError => e
        Appsignal.internal_logger.debug("Pgbus probe: stream metrics failed: #{e.message}")
      end

      def gauge(key, value, tags = {})
        return if value.nil?

        Appsignal.set_gauge("pgbus_#{key}", value, tags)
      end
    end
  end
end
