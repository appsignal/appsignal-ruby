module Appsignal
  module Probes
    # @api private
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
