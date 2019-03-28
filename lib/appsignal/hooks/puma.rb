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
        counts = {
          :backlog => 0,
          :running => 0,
          :pool_capacity => 0,
          :max_threads => 0
        }

        if stats[:worker_status] # Multiple workers
          stats[:worker_status].each do |worker|
            stat = worker[:last_status]

            counts[:backlog] += stat[:backlog]
            counts[:running] += stat[:running]
            counts[:pool_capacity] += stat[:pool_capacity]
            counts[:max_threads] += stat[:max_threads]
          end

          gauge(:workers, stats[:workers], :type => :count)
          gauge(:workers, stats[:booted_workers], :type => :booted)
          gauge(:workers, stats[:old_workers], :type => :old)

        else # Single worker
          counts[:backlog] += stats[:backlog]
          counts[:running] += stats[:running]
          counts[:pool_capacity] += stats[:pool_capacity]
          counts[:max_threads] += stats[:max_threads]
        end

        gauge(:connection_backlog, counts[:backlog])
        gauge(:pool_capacity, counts[:pool_capacity])
        gauge(:threads, counts[:running], :type => :running)
        gauge(:threads, counts[:max_threads], :type => :max)
      end

      private

      attr_reader :hostname

      def gauge(field, count, tags = {})
        Appsignal.set_gauge("puma_#{field}", count, tags.merge(:hostname => hostname))
      end

      def fetch_puma_stats
        ::Puma.stats
      rescue NoMethodError # rubocop:disable Lint/HandleExceptions
      end
    end
  end
end
