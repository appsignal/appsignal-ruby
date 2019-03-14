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
        return unless ::Puma.stats

        stats = JSON.parse Puma.stats, :symbolize_names => true
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

          gauge(:workers, stats[:workers], :kind => :count)
          gauge(:workers, stats[:booted_workers], :kind => :booted)
          gauge(:workers, stats[:old_workers], :kind => :old)

        else # Single worker
          counts[:backlog] += stats[:backlog]
          counts[:running] += stats[:running]
          counts[:pool_capacity] += stats[:pool_capacity]
          counts[:max_threads] += stats[:max_threads]
        end

        gauge(:connections_backlog, counts[:backlog])
        gauge(:running, counts[:running])
        gauge(:pool_capacity, counts[:pool_capacity])
        gauge(:max_threads, counts[:max_threads])
      end

      private

      attr_reader :hostname

      def gauge(field, count, tags = {})
        Appsignal.set_gauge("puma_#{field}", count, tags.merge(:hostname => hostname))
      end
    end
  end
end
