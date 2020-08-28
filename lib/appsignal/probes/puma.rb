require 'net_x/http_unix'

module Appsignal
  module Probes
    class PumaProbe
      def initialize(options={})
        @path = options[:path]
        @auth_token = options[:auth_token]
        @hostname = Appsignal.config[:hostname] || Socket.gethostname
      end

      # @api private
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
        uri = URI.parse(@path)

        address = if uri.scheme =~ /unix/i
                    [uri.scheme, '://', uri.host, uri.path].join
                  else
                    [uri.host, uri.path].join
                  end

        client = NetX::HTTPUnix.new(address, uri.port)

        if uri.scheme =~ /ssl/i
          client.use_ssl = true
          client.verify_mode = OpenSSL::SSL::VERIFY_NONE if ENV['SSL_NO_VERIFY'] == '1'
        end

        get_path = "/stats"
        get_path << "?token=#{@auth_token}" if @auth_token
        req = Net::HTTP::Get.new(get_path)
        resp = client.request(req)
        resp.body
      end
    end
  end
end
