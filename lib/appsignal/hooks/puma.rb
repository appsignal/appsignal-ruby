# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class PumaHook < Appsignal::Hooks::Hook
      register :puma

      def dependencies_present?
        defined?(::Puma)
      end

      def install
        if ::Puma.respond_to?(:stats)
          Appsignal::Minutely.probes.register :puma, PumaProbe
        end

        if ::Puma.respond_to?(:cli_config) && ::Puma.cli_config
          ::Puma.cli_config.options[:before_worker_boot] ||= []
          ::Puma.cli_config.options[:before_worker_boot] << proc do |_id|
            Appsignal.forked
          end

          ::Puma.cli_config.options[:before_worker_shutdown] ||= []
          ::Puma.cli_config.options[:before_worker_shutdown] << proc do |_id|
            Appsignal.stop("puma before_worker_shutdown")
          end
        end

        return unless defined?(::Puma::Cluster)
        # For clustered mode with multiple workers
        ::Puma::Cluster.class_eval do
          alias stop_workers_without_appsignal stop_workers

          def stop_workers
            Appsignal.stop("puma cluster")
            stop_workers_without_appsignal
          end
        end
      end
    end

    class PumaProbe
      def initialize
        @hostname = Appsignal.config[:hostname] || Socket.gethostname
      end

      def call
        puma_stats = fetch_puma_stats
        return unless puma_stats

        stats = JSON.parse puma_stats, :symbolize_names => true
        counts = {}
        count_keys = [:backlog, :running, :pool_capacity, :max_threads]

        if stats[:worker_status] # Multiple workers
          stats[:worker_status].each do |worker|
            stat = worker[:last_status]
            count_keys.each do |key|
              count_if_present counts, key, stat
            end
          end

          gauge(:workers, stats[:workers], :type => :count)
          gauge(:workers, stats[:booted_workers], :type => :booted)
          gauge(:workers, stats[:old_workers], :type => :old)
        else # Single worker
          count_keys.each do |key|
            count_if_present counts, key, stats
          end
        end

        gauge(:connection_backlog, counts[:backlog]) if counts[:backlog]
        gauge(:pool_capacity, counts[:pool_capacity]) if counts[:pool_capacity]
        gauge(:threads, counts[:running], :type => :running) if counts[:running]
        gauge(:threads, counts[:max_threads], :type => :max) if counts[:max_threads]
      end

      private

      attr_reader :hostname

      def gauge(field, count, tags = {})
        Appsignal.set_gauge("puma_#{field}", count, tags.merge(:hostname => hostname))
      end

      def count_if_present(counts, key, stats)
        stat_value = stats[key]
        return unless stat_value
        counts[key] ||= 0
        counts[key] += stat_value
      end

      def fetch_puma_stats
        ::Puma.stats
      rescue NoMethodError # rubocop:disable Lint/HandleExceptions
      end
    end
  end
end
